#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Pod::Xhtml;
use File::Copy;
use File::Spec::Functions qw(rel2abs splitpath splitdir catpath catdir catfile canonpath);

my $input_path      = 'D:/dev/SDL/lib/pods';
   $input_path   = $ARGV[0] if $ARGV[0];

my ($volume, $dirs) = splitpath(rel2abs(__FILE__));
my @directories     = splitdir(canonpath($dirs));
pop(@directories);
my $parent_dir      = catpath($volume, catdir(@directories));
my $pages_path      = catdir($parent_dir, 'pages');
my $assets_path     = catdir($parent_dir, 'htdocs/assets');
my $parser          = Pod::Xhtml->new(FragmentOnly => 1, StringMode => 1, LinkParser => new LinkResolver());
my %module_names    = ();
my %thumbnails      = ();
my %files           = ();
my $fh;

read_file($input_path);

# creating index file
open($fh, '>', File::Spec->catfile($pages_path, 'documentation.html-inc'));
binmode($fh, ":utf8");
print($fh "<div class=\"pod\">\n<h1>Documentation (latest development branch)</h1>");
my $last_section = '';
#for my $module_name (sort keys %module_names)
for my $key (sort keys %files)
{
	my $icon = defined $files{$key}{'thumb'}
	         ? sprintf('<img src="assets/%s" alt="thumb" />', $files{$key}{'thumb'})
	         : sprintf('<img src="assets/bubble-%d-mini.png" alt="thumb" />', int((rand() * 7) + 1));
	         
	my @matches = ( $files{$key}{'section'} =~ m/\w+/xg );
	
	if($#matches)
	{
		my $section_path = '';
		my $doit = 1;
		
		for my $section (@matches)
		{
			last if $section eq $matches[$#matches];
			
			$section_path .= (length($section_path) ? ', ' : '') . $section;
			
			if($last_section =~ /^$section_path/)
			{
				$doit = 0;
			}
		}
	
		if($doit)
		{
			my @this_matches = ( $section_path =~ m/\w+/xg );
			my $i = 0;
			for my $this_section (@this_matches)
			{
				printf($fh '<table style="margin-left: %dpx; margin-top: 5px"><tr><td colspan="3"><strong style="font-size: 14px">%s</strong></td></tr>', 
						   $i++ * 30, $this_section);
			}
		}
	}
	
	if($last_section ne $files{$key}{'section'})
	{
		print ($fh '</table>') if $last_section;
		print ($fh '<br />')  if $last_section && !$#matches;
		printf($fh '<table style="margin-left: %dpx; margin-top: 5px"><tr><td colspan="3"><strong style="font-size: 14px">%s</strong></td></tr>', 
		           $#matches * 30, pop(@matches));
		$last_section = $files{$key}{'section'};
	}
	
	$files{$key}{'desc'} =~ s/^[\-\s]*/- / if $files{$key}{'desc'};
	
	printf($fh '<tr><td>%s</td><td><a href="%s">%s</a></td><td>%s</td></tr>', 
	           $icon, $files{$key}{'path'}, $files{$key}{'name'}, $files{$key}{'desc'});
}
print($fh "</table></div>\n");
close($fh);

sub read_file
{
	my $path = shift;
	my @files      = <$path/*>;

	foreach(@files)
	{
		read_file($_) if(-d $_);
		if($_ =~ /\.pod$/i)
		{
            print "Processing $_\n";
			my $key         = '';
			my $file_name   = $_;
			   $file_name   =~ s/^$input_path\/*//;
			my $module_name = $file_name;
			   $module_name =~ s/\//::/g;
			   $module_name =~ s/(\.pm|\.pod)$//i;
			   $file_name   =~ s/\//-/g;
			   $file_name   =~ s/(\.pm|\.pod)$/.html-inc/i;
			my $file_path   = $file_name;
			   $file_path   =~ s/\-inc$//;
			   $file_name   = File::Spec->catfile($pages_path, $file_name);
			$parser->parse_from_file($_); #, $file_name);
			
			
			
			$key                    = $parser->asString =~ /<div id="CATEGORY_CONTENT">\s*<p>\s*([^<>]+)\s*<\/p>\s*<\/div>/
			                        ? "$1 $_"
			                        : "UNCATEGORIZED/$_";
			$key                    = " $key" if $key =~ /^Core/;
			$files{$key}{'path'}    = $file_path;
			$files{$key}{'name'}    = $module_name;
			$files{$key}{'desc'}    = $parser->asString =~ /<div id="NAME_CONTENT">\s*<p>\s*[^<>\-]+\-([^<>]+)\s*<\/p>\s*<\/div>/
			                        ? $1
			                        : '';
			$files{$key}{'section'} = $parser->asString =~ /<div id="CATEGORY_CONTENT">\s*<p>\s*([^<>]+)\s*<\/p>\s*<\/div>/
			                        ? $1
			                        : 'UNCATEGORIZED';

			# handling images
			my $image_path  = $_;
			   $image_path  =~ s/\.pod$//;
			my @images = <$image_path*>;
			
			my $image_html = '';
			
			foreach my $image_file (@images)
			{
				if($image_file =~ /^($image_path)(_\w+){0,1}\.(jpg|jpeg|png|gif)$/)
				{
					my (undef, undef, $image_file_name) = splitpath($image_file);
					
					if($image_file_name =~ /_thumb\.(jpg|jpeg|png|gif)$/)
					{
						$files{$key}{'thumb'} = $image_file_name;
					}
					else
					{
						$image_html .= sprintf('<a href="assets/%s" target="_blank">'
						                         . '<img src="assets/%s" style="height: 160px" alt="%s"/>'
						                     . '</a>', $image_file_name, $image_file_name, $image_file_name);
					}
										
					copy($image_file, File::Spec->catfile($assets_path, $image_file_name));
				}
			}
			
			# modifying the html-snippet and insert the images
			my $html = $parser->asString;
			   $html =~ s/<!-- INDEX END -->/<!-- INDEX END -->$image_html<hr \/>/ if $image_html;
			
			open($fh, '>', $file_name);
			binmode($fh, ":utf8");
			print($fh $html);
			close($fh);
		}
	}
}

package LinkResolver;
use Pod::ParseUtils;
use base qw(Pod::Hyperlink);

sub new
{
	my $class = shift;
	my $css = shift;
	my $self = $class->SUPER::new();
	return $self;
}

my $warn = 0;
sub node
{
	my $self = shift;

	if($self->SUPER::type() eq 'page')
	{
		my $page = $self->SUPER::page();
		my $suff = '';
		
		if($page =~ /^SDL(x)?\b/)
		{
			$page =~ s/::([A-Z]+)/-$1/g;
			printf "%03d WARNING: " . $self->SUPER::page() . " better written as L<$2|$1/\"$2\">\n", ++$warn if $self->SUPER::page() =~ /(.*)::([a-z_]+)$/;
            
            $page =~ s/(.*)\/"(.*)"/\/$1.html#$2/;
			$page .= '.html' unless $page =~ /\.html/;
			
            #print $self->SUPER::page() . " -> " . $page . "\n" if $page =~ /Event/;
			return $page;
		}
		else
		{
			return "http://search.cpan.org/perldoc?$page";
		}
	}
	elsif($self->SUPER::type() eq 'item')
	{
		my $page = $self->SUPER::page();
		my $node = $self->SUPER::node();
		my $suff = '';
		
		if($page =~ /^SDL(x)?\b/)
		{
			$page =~ s/::([A-Z]+)/-$1/g;
            $node =~ s/&quot;//g;

			return "/$page.html#$node";
		}
		else
		{
			return "http://search.cpan.org/perldoc?$page";
		}
	}
	$self->SUPER::node(@_);
}

sub text
{
	my $self = shift;
	return $self->SUPER::page() if($self->SUPER::type() eq 'page');
	$self->SUPER::text(@_);
}

sub type
{
	my $self = shift;
	return "hyperlink" if($self->SUPER::type() =~ /(page|item)/);
	$self->SUPER::type(@_);
}

1;

