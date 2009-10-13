#!perl

use Test::More 'no_plan';

use JCVI::Range::Set;
use JCVI::Range;

my @a = map { JCVI::Range->new( $_ * 20, 10, 1 ) }  ( 0, 1 );
my @b = map { JCVI::Range->new( $_ * 20, 10, -1 ) } ( 1, 0 );

my ( $A, $B );

ok( JCVI::Range::Set->new(),        'new' );
ok( JCVI::Range::Set->new( $a[0] ), 'new with 1 + strand exon' );
ok( $A = JCVI::Range::Set->new(@a), 'new with 2 + strand exons' );
ok( JCVI::Range::Set->new( $b[0] ), 'new with 1 - strand exon' );
ok( $B = JCVI::Range::Set->new(@b), 'new with 2 - strand exons' );

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

my $a = $A->simplify;
my $b = $B->simplify;

foreach my $def (@battery) {
    my ($test, $pos, $neg) = @$def;
    
    is ($a->$test, $pos, "+ $test bound correct");
    is ($b->$test, $neg, "- $test bound correct");
}
