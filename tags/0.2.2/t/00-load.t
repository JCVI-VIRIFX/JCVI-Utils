#!perl

use Test::More tests => 2;

BEGIN {
	use_ok( 'JCVI::Bounds' );
    use_ok( 'JCVI::Bounds::Set' );
}

diag( "Testing JCVI::Bounds $JCVI::Bounds::VERSION, Perl $], $^X" );
