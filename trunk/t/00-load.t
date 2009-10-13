#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'JCVI::Feature' );
}

diag( "Testing JCVI::Feature $JCVI::Feature::VERSION, Perl $], $^X" );
