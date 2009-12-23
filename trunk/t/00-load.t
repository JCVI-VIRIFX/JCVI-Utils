#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'JCVI::EukDB' );
}

diag( "Testing JCVI::EukDB $JCVI::EukDB::VERSION, Perl $], $^X" );
