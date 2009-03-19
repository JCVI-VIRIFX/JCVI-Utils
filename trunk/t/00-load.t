#!perl

use Test::More tests => 2;

BEGIN {
	use_ok( 'JCVI::Translator' );
    use_ok( 'JCVI::Translator::Utils' );
}

diag( "Testing JCVI::Translator $JCVI::Translator::VERSION, Perl $], $^X" );
diag( "Testing JCVI::Translator::Utils" );
