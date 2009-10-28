package HTML::Zoom;

use strict;
use warnings FATAL => 'all';
use Carp qw(confess);

use HTML::Zoom::EventFilter;
use HTML::Zoom::SelectorParser;
use HTML::Zoom::ActionBuilder;
use HTML::Zoom::Parser::BuiltIn;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  bless({}, $class);
}

sub _clone_with {
  my ($self, %clone) = @_;
  bless({ %$self, %clone }, ref($self));
}

sub from_string {
  my $new = shift->new;
  $new->{source_html} = shift;
  $new;
}

sub from_fh {
  my $new = shift->new;
  my $fh = $_[0];
  $new->{source_html} = do { local $/; <$fh> || die "from_fh: $!" };
  $new;
}

sub with_selectors {
  my $self = shift;
  my $pairs = [];
  while (my @spec = splice(@_, 0, 2)) {
    push(
      @$pairs,
      HTML::Zoom::EventFilter->build_selector_pair(@spec)
    );
  }
  $self->_clone_with(
    _selector_handler => HTML::Zoom::EventFilter->selector_handler($pairs)
  );
}

sub render_to {
  my ($self, $out) = @_;
  $self->_clone_with(
    _emitter => HTML::Zoom::EventFilter->standard_emitter($out)
  )->render;
}

sub render {
  my ($self) = @_;
  my $s_h = $self->{_selector_handler};
  $s_h->set_next($self->{_emitter});
  HTML::Zoom::Parser::BuiltIn::_hacky_tag_parser(
    $self->{source_html}, sub { $s_h->call(@_) }
  );
  $self;
}

=head1 NAME

HTML::Zoom - Lightweight CSS selector based HTML templating

=head1 SYNOPSIS

  use HTML::Zoom;

  my $html = <<HTML;
  <html>
    <head>
      <title>Hello people</title>
    </head>
    <body>
      <h1 id="greeting">Placeholder</h1>
      <div id="list">
        <span>
          <p>Name: <span class="name">Bob</span></p>
          <p>Age: <span class="age">23</span></p>
        </span>
        <hr class="between" />
      </div>
    </body>
  </html>
  HTML

  HTML::Zoom->from_string($html)
            ->add_selectors(
                'title, #greeting' => 'Hello world & dog!',
                '#list' => [
                  { '.name' => 'Matt',
                    '.age' => 26
                  },
                  { '.name' => 'Mark',
                    '.age' => '0x29'
                  },
                  { '.name' => 'Epitaph',
                    '.age' => '<redacted>'
                  },
                  'span:odd p' => { -add_class => 'alt' },
                ]
              )
            ->stream_to(\*STDOUT)
            ->render;

will print -

  <html>
    <head>
      <title>Hello world &amp; dog!</title>
    </head>
    <body>
      <h1 id="greeting">Hello world &amp; dog!</h1>
      <div id="list">
        <span>
          <p>Name: <span class="name">Matt</span></p>
          <p>Age: <span class="age">26</span></p>
        <span>
        <hr class="between" />
        <span>
          <p class="alt">Name: <span class="name">Mark</span></p>
          <p class="alt">Age: <span class="age">0x29</span></p>
        <span>
        <hr class="between" />
        <span>
          <p>Name: <span class="name">Epitaph</span></p>
          <p>Age: <span class="age">&lt;redacted&gt;</span></p>
        <span>
      </div>
    </body>
  </html>

Using a layout -

  <html>
    <head>
      <title>default title</title>
    </head>
    <body>
      <img src="/logo.jpg" />
    </body>
  </html>

=head1 SELECTORS

http://docs.jquery.com/Selectors

=cut

1;
