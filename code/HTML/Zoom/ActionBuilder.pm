package HTML::Zoom::ActionBuilder;

use strict;
use warnings FATAL => 'all';

use HTML::Zoom::Parser::BuiltIn;
use HTML::Zoom::EventFilter;
use Storable ();
use Carp qw(confess);

sub build {
  my ($tb, $name, @args) = @_;
  confess "Don't know how to build ${name} in ${tb}"
    unless $tb->can("build_${name}");

  return $tb->${\"build_${name}"}(@args);
}

sub build_add_attribute {
  my ($tb, $name, $value) = @_;
  sub {
    my ($self, $evt) = @_;
    delete @{$evt}{qw(raw raw_attrs)};
    if (defined $evt->{attrs}{$name}) {
      $evt->{attrs}{$name} .= ' '.$value;
    } else {
      $evt->{attrs}{$name} = $value;
    }
  };
}

sub build_set_attribute {
  my ($tb, $name, $value) = @_;
  sub {
    my ($self, $evt) = @_;
    delete @{$evt}{qw(raw raw_attrs)};
    $evt->{attrs}{$name} = $value;
  };
}

sub build_add_class { shift->build_add_attribute('class' => @_) }
sub build_set_class { shift->build_set_attribute('class' => @_) }

sub build_replace_content {
  my ($tb, $text) = @_;
  my $raw = HTML::Zoom::Parser::BuiltIn::_simple_escape($text);
  $tb->build_replace_content_raw($raw);
}

sub build_replace_content_raw {
  my ($tb, $raw) = @_;
  sub {
    my ($self, $evt) = @_;
    my $in_place_close = $evt->{is_in_place_close};
    if ($in_place_close) {
      delete $evt->{raw};
      $evt->{is_in_place_close} = 0;
    }
    $self->until_close_do_last(
      undef,
      sub {
        delete $_[1]->{raw} if $in_place_close;
        $_[0]->next({ type => 'TEXT', raw => $raw })
      }
    )
  };
}

sub build_repeat {
  my ($tb, $args) = @_;
  my $data = $args->{data};
  my $do_repeat = sub {
    my ($self, $to_repeat) = @_;
    my $stole_last;
    if ($to_repeat->[-1]->{type} eq 'TEXT') {
      if ($to_repeat->[-1]->{raw} =~ s/(\s+)$//) {
        $stole_last = $1;
      }
    }
    foreach my $d (@$data) {
      my @pairs = map {
        HTML::Zoom::EventFilter->build_selector_pair($_, $d->{$_})
      } sort keys %$d;
      my $sel = HTML::Zoom::EventFilter->selector_handler(\@pairs);
      $sel->set_next($self->get_next);
      $sel->call($_) for @$to_repeat;
    }
    if (defined $stole_last) {
      $self->next({ type => 'TEXT', raw => $stole_last });
    }
  };
  sub {
    my ($self, $evt) = @_;
    return if $evt->{is_in_place_close}; # no content to repeat
    my @repeat;
    $self->until_close_do_last(
       sub { push(@repeat, $_[1]) },
       sub { $_[0]->$do_repeat(\@repeat) },
    );
  };
}

1;
