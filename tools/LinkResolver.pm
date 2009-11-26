
package LinkResolver;
use Pod::ParseUtils;
use base qw(Pod::Hyperlink);

sub new
{
	my $class = shift;
	my $css = shift;
	my $self = $class->SUPER::new();
	$self->{css} = $css;
	return $self;
}

sub node
{
	my $self = shift;
	if($self->SUPER::type() eq 'page')
	{
		my $url = "?module=".$self->SUPER::page();
		$url.=";css=".$_ for @{$self->{css}};
		return $url;
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
	return "hyperlink" if($self->SUPER::type() eq 'page');
	$self->SUPER::type(@_);
}

1;

