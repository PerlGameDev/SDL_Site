package Web::Simple;

use strict;
use warnings FATAL => 'all';

sub import {
  strict->import;
  warnings->import(FATAL => 'all');
  warnings->unimport('syntax');
  warnings->import(FATAL => qw(
    ambiguous bareword digit parenthesis precedence printf
    prototype qw reserved semicolon
  ));
  my ($class, $app_package) = @_;
  $class->_export_into($app_package);
}

sub _export_into {
  my ($class, $app_package) = @_;
  {
    no strict 'refs';
    *{"${app_package}::dispatch"} = sub {
      $app_package->_setup_dispatchables(@_);
    };
    *{"${app_package}::filter_response"} = sub (&) {
      $app_package->_construct_response_filter($_[0]);
    };
    *{"${app_package}::redispatch_to"} = sub {
      $app_package->_construct_redispatch($_[0]);
    };
    *{"${app_package}::default_config"} = sub {
      my @defaults = @_;
      *{"${app_package}::_default_config"} = sub { @defaults };
    };
    *{"${app_package}::self"} = \${"${app_package}::self"};
    require Web::Simple::Application;
    unshift(@{"${app_package}::ISA"}, 'Web::Simple::Application');
  }
}

1;
