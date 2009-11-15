#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use File::Spec::Functions qw(rel2abs splitpath splitdir catpath catdir catfile canonpath);
use XML::Feed;

my $feed            = XML::Feed->parse(URI->new('http://yapgh.blogspot.com/feeds/posts/default?alt=rss'))
                      or die XML::Feed->errstr;

my ($volume, $dirs) = splitpath(rel2abs(__FILE__));

my @directories     = splitdir(canonpath($dirs));
pop(@directories);
my $parent_dir      = catpath($volume, catdir(@directories));
my $output_path     = catdir($parent_dir, 'pages');

die("Error: Output path '$output_path' not found.") unless(-d $output_path);

my $fh;
my %available_tags  = (); # tags to filenames
my %tag_overview    = (); # tags to short content

printf("path for placing files is: %s\n", $output_path);

my $i = 1;
for my $entry ($feed->entries)
{
    my $output_file = sprintf("blog-%04d.html-inc", $i);
    my @tags        = $entry->tags;
	
    foreach my $tag (sort @tags)
    {
    	@{$available_tags{$tag}} = () unless defined ($available_tags{$tag});
    	push(@{$available_tags{$tag}}, $output_file);
    }

	open($fh, '>', catfile($output_path, $output_file));
	binmode($fh, ":utf8");
	print($fh "<div class=\"blog\">\n<h1 id=\"NAME\">\n",
	          $entry->title, 
	          "\n</h1>\n<div class=\"CONTENT\">\n", 
	          $entry->content->body, 
			  "</div>",
	          "</div>"
	);
	close($fh);
	
	printf("created file: %s\n", $output_file);

	$i++;
}

open($fh, '>', catfile($output_path, 'blog-0000.html-inc'));
binmode($fh, ":utf8");
print($fh "<div class=\"blog\"><h1>Articles</h1>\n");
$i = 1;
for my $entry ($feed->entries)
{
	my $tag_links = '';
    my @tags      = $entry->tags;
    foreach my $tag (sort @tags)
    {
		my $_tag   = $tag;
		   $_tag   =~ s/\W/-/g;
    	$tag_links .= sprintf(' <a href="tags-%s.html" style="font-size: 10px">[%s]</a>', $_tag, $tag);
    }

	my $text = $entry->content->body;
	   $text = $1 if $text =~ /^<div.+<\/div>(.+)<div.+<\/div>$/;
	   $text =~ s/<br\s*\/{0,1}>/\n/g;
	   $text =~ s/<[@#%\w\s"\/?&=:\-\.;']+>/ /g;
	   $text =~ s/^\n*//g;
	   $text =~ s/\n*$//g;
	   $text =~ s/\n+/\n/g;
	   $text =~ s/\n/<br \/>/g;
	   $text = $1 if $text =~ /^([^<>]+<br \/>[^<>]+<br \/>[^<>]+<br \/>).*$/;
	   $text =~ s/(<br \/>)+$//g;
	   
	# overview of all blog entries
	printf($fh '<div>'
	             . '<a href="blog-%04d.html">%s</a><br />'
	             . '<span style="font-size: 10px">%s</span><br />'
	             . '<span style="font-size: 10px">Tags:</span>%s<br />'
			     . '%s<br /><a href="blog-%04d.html" style="font-size: 12px">[more]</a><br /><br />'
			 . '</div>'
			 . '<hr />',
		$i, $entry->title, $entry->issued->strftime('%A, %d %B %Y'), $tag_links, $text, $i
	);

	# preparing the %tag_overview hash for tag-overview-pages
    @tags      = $entry->tags;
    foreach my $tag (sort @tags)
    {
    	@{$tag_overview{$tag}} = () unless defined ($tag_overview{$tag});
    	push(@{$tag_overview{$tag}}, 
			sprintf('<div>'
					 . '<a href="blog-%04d.html">%s</a><br />'
					 . '<span style="font-size: 10px">%s</span><br />'
					 . '<span style="font-size: 10px">Tags: %s</span><br />'
					 . '%s<br /><a href="blog-%04d.html" style="font-size: 12px">[more]</a><br /><br />'
				 . '</div>',
			$i, $entry->title, $entry->issued->strftime('%A, %d %B %Y'), $tag_links, $text, $i
		));
    }

	$i++;
}
print($fh "</div>\n");
close($fh);
printf("created file: %s\n", 'blog-0000.html-inc');


# csv: "tagname: file1,file2\n"
open($fh, '>', catfile($output_path, 'tags-index'));
binmode($fh, ":utf8");
foreach my $tag (sort keys %available_tags)
{
	printf($fh "%s: %s\n", $tag, join(',', @{$available_tags{$tag}}));
}
close($fh);
printf("created file: %s\n", 'tags-index');

# overview pages for tags
foreach my $tag (sort keys %tag_overview)
{
	my $_tag = $tag;
       $_tag =~ s/\W/-/g;
	open($fh, '>', catfile($output_path, 'tags-' . $_tag . '.html-inc'));
	binmode($fh, ":utf8");
	print($fh '<div class="blog"><h1>Results for tag: ' . $tag . '</h1>' 
	        . join('<hr />', @{$tag_overview{$tag}})
			. '</div>');
	close($fh);
	printf("created file: %s\n", 'tags-' . $_tag . '.html-inc');
}

