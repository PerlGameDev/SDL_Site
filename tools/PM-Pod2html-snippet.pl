#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use Pod::Xhtml;
use File::Spec::Functions qw(rel2abs splitpath splitdir catpath catdir catfile canonpath);

my $input_path      = 'C:/SDL_perl/lib/pods';
   $input_path   = $ARGV[0] if $ARGV[0];

my ($volume, $dirs) = splitpath(rel2abs(__FILE__));
my @directories     = splitdir(canonpath($dirs));
pop(@directories);
my $parent_dir      = catpath($volume, catdir(@directories));
my $output_path     = catdir($parent_dir, 'pages');
my $parser          = Pod::Xhtml->new(FragmentOnly => 1);
my %module_names    = ();
my $fh;

read_file($input_path);

# creating index file
open($fh, '>', File::Spec->catfile($output_path, 'documentation.html-inc'));
binmode($fh, ":utf8");
print($fh "<div class=\"pod\">\n<h1>Documentation (latest development branch)</h1>");
for my $module_name (sort keys %module_names)
{
	print($fh '<a href="' . $module_names{$module_name} . '">',
	          $module_name, 
	          '</a><br />'
	);
}
print($fh "</div>\n");
close($fh);

sub read_file
{
	my $path = shift;
	my @files      = <$path/*>;

	foreach(@files)
	{
		read_file($_) if(-d $_);
		carp "Invalid directory $_" if !(-d $_);
		if($_ =~ /\.pod$/i)
		{
			my $file_name   = $_;
			   $file_name   =~ s/^$input_path\/*//;
			my $module_name = $file_name;
			   $module_name =~ s/\//::/g;
			   $module_name =~ s/(\.pm|\.pod)$//i;
			   $file_name   =~ s/\//-/g;
			   $file_name   =~ s/(\.pm|\.pod)$/.html-inc/i;
			my $file_path   = $file_name;
			   $file_path   =~ s/\-inc$//;
			$module_names{$module_name} = $file_path;
			   $file_name   = File::Spec->catfile($output_path, $file_name);

			$parser->parse_from_file($_, $file_name);
		}
	}
}