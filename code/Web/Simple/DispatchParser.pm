package Web::Simple::DispatchParser;

use strict;
use warnings FATAL => 'all';

sub new { bless({}, ref($_[0])||$_[0]) }

sub _blam {
  my ($self, $error) = @_;
  my $hat = (' ' x pos).'^';
  die "Error parsing dispatch specification: ${error}\n
${_}
${hat} here\n";
}

sub parse_dispatch_specification {
  my ($self, $spec) = @_;
  for ($spec) {
    my @match;
    local $self->{already_have};
    /^\G\s*/; # eat leading whitespace
    PARSE: { do {
      push @match, $self->_parse_spec_section($spec)
        or $self->_blam("Unable to work out what the next section is");
      last PARSE if (pos == length);
      /\G\+/gc or $self->_blam('Spec sections must be separated by +');
    } until (pos == length) }; # accept trailing whitespace
    return $match[0] if (@match == 1);
    return sub {
      my $env = { %{$_[0]} };
      my $new_env;
      my @got;
      foreach my $match (@match) {
        if (my @this_got = $match->($env)) {
          my %change_env = %{shift(@this_got)};
          @{$env}{keys %change_env} = values %change_env;
          @{$new_env}{keys %change_env} = values %change_env;
          push @got, @this_got;
        } else {
          return;
        }
      }
      return ($new_env, @got);
    };
  }
}

sub _dupe_check {
  my ($self, $type) = @_;
  $self->_blam("Can't have more than one ${type} match in a specification")
    if $self->{already_have}{$type};
  $self->{already_have}{$type} = 1;
}

sub _parse_spec_section {
  my ($self) = @_;
  for ($_[1]) {

    # GET POST PUT HEAD ...

    /\G([A-Z]+)/gc and
      return $self->_http_method_match($_, $1);

    # /...

    /\G(?=\/)/gc and
      return $self->_url_path_match($_);

    /\G\.(\w+)/gc and
      return $self->_url_extension_match($_, $1);
  }
  return; # () will trigger the blam in our caller
}

sub _http_method_match {
  my ($self, $str, $method) = @_;
  $self->_dupe_check('method');
  sub { shift->{REQUEST_METHOD} eq $method ? {} : () };
}

sub _url_path_match {
  my ($self) = @_;
  $self->_dupe_check('path');
  for ($_[1]) {
    my @path;
    while (/\G\//gc) {
      push @path, $self->_url_path_segment_match($_)
        or $self->_blam("Couldn't parse path match segment");
    }
    my $re = '^()'.join('/','',@path).'$';
    return sub {
      if (my @cap = (shift->{PATH_INFO} =~ /$re/)) {
        $cap[0] = {}; return @cap;
      }
      return ();
    };
  }
  return;
}

sub _url_path_segment_match {
  my ($self) = @_;
  for ($_[1]) {
    # trailing / -> require / on end of URL
    /\G(?:(?=\s)|$)/gc and
      return '$';
    # word chars only -> exact path part match
    /\G(\w+)/gc and
      return "\Q$1";
    # ** -> capture unlimited path parts
    /\G\*\*/gc and
      return '(.+?)';
    # * -> capture path part
    /\G\*/gc and
      return '([^/]+)';
  }
  return ();
}

sub _url_extension_match {
  my ($self, $str, $extension) = @_;
  $self->_dupe_check('extension');
  sub {
    if ((my $tmp = shift->{PATH_INFO}) =~ s/\.\Q${extension}\E$//) {
      ({ PATH_INFO => $tmp });
    } else {
      ();
    }
  };
}

1;
