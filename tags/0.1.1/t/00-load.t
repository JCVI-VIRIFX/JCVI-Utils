#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'JCVI::Location' );
}

diag( "Testing JCVI::Location $JCVI::Location::VERSION, Perl $], $^X" );
