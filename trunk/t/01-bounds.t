#!perl

use Test::More tests => 27;

use JCVI::Range;

ok( JCVI::Range->new(),   'new' );
ok( JCVI::Range->new(10), 'new with lower' );
ok( JCVI::Range->new( 10, 10 ), 'new with lower/length' );
ok( JCVI::Range->new( 10, 10, 1 ), 'new with lower/length/strand' );

# Tests for failure

eval { JCVI::Range->new(-10) };
ok( $@, 'negative lower' );

eval { JCVI::Range->new('a') };
ok( $@, 'letter lower' );

eval { JCVI::Range->new('5a') };
ok( $@, 'letter + number lower' );

eval { JCVI::Range->new( 0, -10 ) };
ok( $@, 'negative length' );

eval { JCVI::Range->new( 0, 'a' ) };
ok( $@, 'letter length' );

eval { JCVI::Range->new( 0, '5a' ) };
ok( $@, 'letter + number length' );

eval { JCVI::Range->new( 0, 0, 2 ) };
ok( $@, 'invalid number strand' );

eval { JCVI::Range->new( 0, 0, 'a' ) };
ok( $@, 'letter strand' );

eval { JCVI::Range->new( 0, 0, '-1a' ) };
ok( $@, 'letter + number strand' );

# Test that range are proper
my $range = JCVI::Range->new( 50, 100, -1 );
is( $range->lower,  50,  'lower correct' );
is( $range->length, 100, 'length correct' );
is( $range->strand, -1,  'strand correct' );
is( $range->upper,  150, 'upper correct' );
is( $range->end5,   150, 'end5 correct' );
is( $range->end3,   51,  'end3 correct' );

ok( JCVI::Range->new_53( 1, 10 ), 'new_53 works' );

my $e53 = JCVI::Range->new_53( 150, 51 );
is_deeply( $e53, $range, 'new_53 == new' );

# Test range modification
$range->lower(60);
is( $range->lower,  60,  'lower correct' );
is( $range->length, 90, 'length correct' );
is( $range->upper,  150, 'upper correct' );

$range->upper(80);
is( $range->lower,  60, 'lower correct' );
is( $range->length, 20, 'length correct' );
is( $range->upper,  80, 'upper correct' );
