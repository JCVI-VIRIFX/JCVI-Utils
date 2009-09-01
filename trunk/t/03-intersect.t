use strict;

use Test::More 'no_plan';
use JCVI::Bounds;

my @bounds;

my $start = 0;
foreach my $strand ( 1, -1 ) {
    foreach ( 0, 1 ) {
        push @bounds, JCVI::Bounds->new( $start++, 5, $strand );
    }
}

my @e1 = (
    [ [ 0, 5, 1 ], [ 1, 4, 1 ], [ 2, 3, undef ], [ 3, 2, undef ] ],
    [ [ 1, 4, 1 ], [ 1, 5, 1 ], [ 2, 4, undef ], [ 3, 3, undef ] ],
    [ [ 2, 3, undef ], [ 2, 4, undef ], [ 2, 5, -1 ], [ 3, 4, -1 ] ],
    [ [ 3, 2, undef ], [ 3, 3, undef ], [ 3, 4, -1 ], [ 3, 5, -1 ] ]
);

foreach my $i ( 0 .. 3 ) {
    $a = $bounds[$i];

    my $e2 = shift @e1;

    foreach my $j ( 0 .. 3 ) {
        my $b = $bounds[$j];
        my $e3 = shift @$e2;
        my $c = $a->intersection($b);
        is_deeply( [@$c], $e3, "Intersection $i $j" );
    }
}
