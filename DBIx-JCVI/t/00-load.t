#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'DBIx::JCVI' );
}

diag( "Testing DBIx::JCVI $DBIx::JCVI::VERSION, Perl $], $^X" );
