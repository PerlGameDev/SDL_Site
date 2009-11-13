#!/usr/bin/env perl

use strict;
use warnings;

use File::Spec;
use Pod::Xhtml;

die "Usage: pod2xhtml filename\n" if $#ARGV < 0;

my $parser       = Pod::Xhtml->new(FragmentOnly => 1);

my $file_name    = $ARGV[0];
$file_name       =~ s/(\.pm|\.pod)$/.html-inc/i;
$parser->parse_from_file($ARGV[0], $file_name);
