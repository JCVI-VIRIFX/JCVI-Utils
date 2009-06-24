#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'DBIx::SQSHRC' );
}

diag( "Testing DBIx::SQSHRC $DBIx::SQSHRC::VERSION, Perl $], $^X" );
