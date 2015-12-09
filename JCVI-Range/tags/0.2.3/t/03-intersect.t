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
    [ [ 0, 5, 1 ], [ 1, 5, 1 ], [ 2, 5 ], [ 3, 5 ] ],
    [ [ 1, 5, 1 ], [ 1, 6, 1 ], [ 2, 6 ], [ 3, 6 ] ],
    [ [ 2, 5 ], [ 2, 6 ], [ 2, 7, -1 ], [ 3, 7, -1 ] ],
    [ [ 3, 5 ], [ 3, 6 ], [ 3, 7, -1 ], [ 3, 8, -1 ] ]
);

foreach my $a (@bounds) {
    my $e2 = shift @e1;
    foreach my $b (@bounds) {
        my $e3 = shift @$e2;

        my $i = $a->intersection($b);

        diag("$a");
        diag("$b");
        is( $i->lower,  $e3->[0], "lower" );
        is( $i->upper,  $e3->[1], "upper" );
        is( $i->strand, $e3->[2], "strand" )
          if ( $e3->[2] );
    }
}
