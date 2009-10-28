package HTML::Zoom::Parser::BuiltIn;

sub _hacky_tag_parser {
  my ($text, $handler) = @_;
  while (
    $text =~ m{
      (
        (?:[^<]*) < (?:
            ( / )? ( [^/!<>\s"'=]+ )
            ( (?:"[^"]*"|'[^']*'|[^"'<>])+? )?
        |   
            (!-- .*? -- | ![^\-] .*? )
        ) (\s*/\s*)? >
      )
      ([^<]*)
    }sxg
  ) {
    my ($whole, $is_close, $tag_name, $attributes, $is_comment,
        $in_place_close, $content)
      = ($1, $2, $3, $4, $5, $6, $7, $8);
    next if defined $is_comment;
    $tag_name =~ tr/A-Z/a-z/;
    if ($is_close) {
      $handler->({ type => 'CLOSE', name => $tag_name, raw => $whole });
    } else {
      $attributes = '' if $attributes =~ /^ +$/;
      $handler->({
        type => 'OPEN',
        name => $tag_name,
        is_in_place_close => $in_place_close,
        _hacky_attribute_parser($attributes),
        raw_attrs => $attributes||'',
        raw => $whole,
      });
      if ($in_place_close) {
        $handler->({
          type => 'CLOSE', name => $tag_name, raw => '',
          is_in_place_close => 1
        });
      }
    }
    if (length $content) {
      $handler->({ type => 'TEXT', raw => $content });
    }
  }
}

sub _hacky_attribute_parser {
  my ($attr_text) = @_;
  my (%attrs, @attr_names);
  while (
    $attr_text =~ m{
      ([^\s\=\"\']+)(\s*=\s*(?:(")(.*?)"|(')(.*?)'|([^'"\s=]+)['"]*))?
    }sgx
  ) {
    my $key  = $1;
    my $test = $2;
    my $val  = ( $3 ? $4 : ( $5 ? $6 : $7 ));
    my $lckey = lc($key);
    if ($test) {
      $attrs{$lckey} = _simple_unescape($val);
    } else {
      $attrs{$lckey} = $lckey;
    }
    push(@attr_names, $lckey);
  }
  (attrs => \%attrs, attr_names => \@attr_names);
}

sub _simple_unescape {
  my $str = shift;
  $str =~ s/&quot;/"/g;
  $str =~ s/&lt;/</g;
  $str =~ s/&gt;/>/g;
  $str =~ s/&amp;/&/g;
  $str;
}

sub _simple_escape {
  my $str = shift;
  $str =~ s/&/&amp;/g;
  $str =~ s/"/&quot;/g;
  $str =~ s/</&lt;/g;
  $str =~ s/>/&gt;/g;
  $str;
}

1;
