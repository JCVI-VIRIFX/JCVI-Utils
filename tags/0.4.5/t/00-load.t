#!perl

use Test::More tests => 4;

BEGIN {
	use_ok( 'JCVI::Bounds' );
    use_ok( 'JCVI::Bounds::Set' );
    use_ok( 'JCVI::Bounds::Interface' );
    use_ok( 'JCVI::Bounds::Set::Interface' );
}

diag( "Testing JCVI::Bounds $JCVI::Bounds::VERSION, Perl $], $^X" );
