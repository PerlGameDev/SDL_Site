package HTML::Zoom::EventFilter;

use strict;
use warnings FATAL => 'all';
use Carp qw(confess);

sub from_code {
  my ($class, $code) = @_;
  confess "from_code is a class method" if ref $class;
  bless({ code => $code }, $class);
}

sub next {
  my $n = shift->{next} or return;
  $n->${\$n->{code}}(@_);
}

sub call {
  $_[0]->{code}->(@_);
}

sub set_next {
  $_[0]->{next} = $_[1];
  $_[0];
}

sub get_next { $_[0]->{next} }

sub push_next {
  my ($self, $code) = @_;
  $self->{next} = bless(
    { code => $code, next => $self->{next} }
  );
}

sub push_last {
  my ($self, $code) = @_;
  my $target = $self;
  while ($target->{next} && $target->{next}{next}) {
    $target = $target->{next}
  }
  $target->push_next($code);
}

sub pop {
  my ($self, $to) = @_;
  die "$self doesn't have a next (->pop($to))"
    unless $self->{next};
  my $target = $self;
  until ($target->{next} eq $to) {
    $target = $target->{next} || die "Didn't find $to as next of $self";
  }
  $target->{next} = $to->{next};
  $_[0];
}

sub until_close_do_next { shift->until_close_do(next => @_) }
sub until_close_do_last { shift->until_close_do(last => @_) }

sub until_close_do {
  my ($self, $direction, $do, $before_close, $after_close) = @_;
  my %depth = (OPEN => 1, CLOSE => -1, TEXT => 0);
  my $count = 1;
  my $outer = $self;
  $self->${\"push_${direction}"}(
    sub {
      my ($self, $evt) = @_;
      $count += $depth{$evt->{type}};
      if ($count) {
        $do->(@_, $count) if $do;
        return;
      }
      $before_close->($self, $evt) if $before_close;
      $outer->pop($self)->next($evt);
      $after_close->($outer, $evt) if $after_close;
    }
  )
}

sub standard_emitter {
  my ($class, $out) = @_;
  confess "standard_emitter is a class method" if ref $class;
  $class->from_code(sub {
    my ($self, $evt) = @_;
    return $out->print($evt->{raw}) if defined $evt->{raw};
    if ($evt->{type} eq 'OPEN') {
      $out->print(
        '<'
        .$evt->{name}
        .(defined $evt->{raw_attrs}
            ? $evt->{raw_attrs}
            : do {
                my @names = @{$evt->{attr_names}};
                @names
                  ? join(' ', '', map qq{${_}="${\$evt->{attrs}{$_}}"}, @names)
                  : ''
              }
         )
        .($evt->{is_in_place_close} ? ' /' : '')
        .'>'
      );
    } elsif ($evt->{type} eq 'CLOSE') {
      $out->print('</'.$evt->{name}.'>');
    } else {
      confess "No raw value in event and no special handling for type ".$evt->{type};
    }
  });
}

sub selector_handler {
  my ($class, $pairs) = @_;
  confess "selector_handler is a class method" if ref $class;
  $class->from_code(sub {
    my ($self, $evt) = @_;
    my $next = $self->get_next;
    if ($evt->{type} eq 'OPEN') {
      foreach my $p (@$pairs) {
        $p->[1]->($self, $evt) if $p->[0]->($evt);
      }
    }
    $next->call($evt);
  });
}

sub build_selector_pair {
  my ($class, $sel_spec, $action_spec) = @_;
  my $selector = HTML::Zoom::SelectorParser->parse_selector($sel_spec);
  my $action;
  if (ref($action_spec) eq 'HASH') {
    confess "hash spec must be single key"
      unless keys(%$action_spec) == 1;
    my ($key) = keys (%$action_spec);
    $key =~ s/^-//;
    $action = HTML::Zoom::ActionBuilder->build($key, values %$action_spec);
  }
  [ $selector, $action ];
}

1;
