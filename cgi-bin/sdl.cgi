#!/usr/bin/perl

use FindBin;
use lib $FindBin::RealBin.'/../code';
use Web::Simple 'SDL_Perl::WebSite';

sub SDL_Perl::WebSite::Page::html { ${+shift} }

package SDL_Perl::WebSite;

use HTML::Zoom;

default_config(
  pages_dir => $FindBin::RealBin.'/../pages',
  layout_file => $FindBin::RealBin.'/../layout.html',
);

sub page {
  my ($self, $page) = @_;
  my $file = $self->config->{pages_dir}.'/'.$page.'.html-inc';
  return () unless -e $file;
  return bless(
    \do { local (@ARGV, $/) = $file; <> },
    'SDL_Perl::WebSite::Page'
  )
}

dispatch [
  sub (GET + /) { redispatch_to '/index.html' },
  sub (GET + /**/) {
    redispatch_to join('/','',$_[1],'index.html');
  },
  sub (.html) {
    filter_response { $self->render_html($_[1]) }
  },
  sub (GET + /**) {
    $self->page($_[1])
  },
];

{ my $DATA; sub _read_data { $DATA ||= do { local $/; <DATA>; } } }

sub layout_zoom {
  my $self = shift;
  $self->{layout_zoom} ||= do {
    HTML::Zoom->from_string($self->_layout_html)
  };
}

sub _layout_html {
  my $self = shift;
  my $file = $self->config->{layout_file};
  if (-f $file) {
    return do { local(@ARGV, $/) = ($file); <> }
  } else {
    return $self->_read_data
  }
}

sub render_html {
  my ($self, $data) = @_;
  return $data if ref($data) eq 'ARRAY';
  my ($zoom) = map {
    if ($data->isa('SDL_Perl::WebSite::Page')) {
      $_->with_selectors(
        '#main' => {
          -replace_content_raw => $data->html
        }
      );
    } else {
      die "WTF is ${data} supposed to be? A mallard?";
    }
  } ($self->layout_zoom);
  $self->zoom_to_response($zoom);
}

sub zoom_to_response {
  my ($self, $zoom) = @_;
  open my $fh, '>', \my $out_str;
  $zoom->render_to($fh);
  return [
    200,
    [ 'Content-type' => 'text/html' ],
    [ $out_str ]
  ];
}


SDL_Perl::WebSite->run_if_script;
__DATA__
<html>
  <body>
    <div id="main"/>
  </body>
</html>
