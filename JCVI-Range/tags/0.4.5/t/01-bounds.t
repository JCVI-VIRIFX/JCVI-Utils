#!perl

use Test::More tests => 28;

use JCVI::Bounds;

ok( JCVI::Bounds->new(),   'new' );
ok( JCVI::Bounds->new(10), 'new with lower' );
ok( JCVI::Bounds->new( 10, 10 ), 'new with lower/length' );
ok( JCVI::Bounds->new( 10, 10, 1 ), 'new with lower/length/strand' );

# Tests for failure

eval { JCVI::Bounds->new(-10) };
ok( $@, 'negative lower' );

eval { JCVI::Bounds->new('a') };
ok( $@, 'letter lower' );

eval { JCVI::Bounds->new('5a') };
ok( $@, 'letter + number lower' );

eval { JCVI::Bounds->new( 0, -10 ) };
ok( $@, 'negative length' );

eval { JCVI::Bounds->new( 0, 'a' ) };
ok( $@, 'letter length' );

eval { JCVI::Bounds->new( 0, '5a' ) };
ok( $@, 'letter + number length' );

eval { JCVI::Bounds->new( 0, 0, 2 ) };
ok( $@, 'invalid number strand' );

eval { JCVI::Bounds->new( 0, 0, 'a' ) };
ok( $@, 'letter strand' );

eval { JCVI::Bounds->new( 0, 0, '-1a' ) };
ok( $@, 'letter + number strand' );

# Test that bounds are proper
my $bounds = JCVI::Bounds->new( 50, 100, -1 );
is( $bounds->lower,  50,  'lower correct' );
is( $bounds->length, 100, 'length correct' );
is( $bounds->strand, -1,  'strand correct' );
is( $bounds->upper,  150, 'upper correct' );
is( $bounds->phase,  1,   'phase correct' );
is( $bounds->end5,   150, 'end5 correct' );
is( $bounds->end3,   51,  'end3 correct' );

ok( JCVI::Bounds->e53( 1, 10 ), 'e53 works' );

my $e53 = JCVI::Bounds->e53( 150, 51 );
is_deeply( $e53, $bounds, 'e53 == new' );

# Test bounds modification
$bounds->lower(60);
is( $bounds->lower,  60,  'lower correct' );
is( $bounds->length, 90, 'length correct' );
is( $bounds->upper,  150, 'upper correct' );

$bounds->upper(80);
is( $bounds->lower,  60, 'lower correct' );
is( $bounds->length, 20, 'length correct' );
is( $bounds->upper,  80, 'upper correct' );
