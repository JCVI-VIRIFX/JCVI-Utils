#!perl

use Test::More 'no_plan';

use JCVI::Bounds::Set;
use JCVI::Bounds;

my @a = map { JCVI::Bounds->new( $_ * 20, 10, 1 ) }  ( 0, 1 );
my @b = map { JCVI::Bounds->new( $_ * 20, 10, -1 ) } ( 1, 0 );

my ( $A, $B );

ok( JCVI::Bounds::Set->new(),        'new' );
ok( JCVI::Bounds::Set->new( $a[0] ), 'new with 1 + strand exon' );
ok( $A = JCVI::Bounds::Set->new(@a), 'new with 2 + strand exons' );
ok( JCVI::Bounds::Set->new( $b[0] ), 'new with 1 - strand exon' );
ok( $B = JCVI::Bounds::Set->new(@b), 'new with 2 - strand exons' );

my @battery = (
    [ 'lower',  0,  0 ],
    [ 'upper',  30, 30 ],
    [ 'strand', 1,  -1 ],
    [ 'end5',   1,  30 ],
    [ 'end3',   30, 1 ]
);

foreach my $def (@battery) {
    my ($test, $pos, $neg) = @$def;
    
    is ($A->$test, $pos, "+ $test correct");
    is ($B->$test, $neg, "- $test correct");
}

my $a = $A->bounds;
my $b = $B->bounds;

foreach my $def (@battery) {
    my ($test, $pos, $neg) = @$def;
    
    is ($a->$test, $pos, "+ $test bound correct");
    is ($b->$test, $neg, "- $test bound correct");
}