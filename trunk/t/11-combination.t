use strict;

# Array of tests
# ( [ [ Range 1 ], [ Range 2 ], [ Intersection ], [ Overlap ] ], ... )
# Where the ranges are defined as:
# [ $lower, $upper, $strand ]

my @TESTS;

BEGIN {
    @TESTS = (
        [ [ 48, 58, -1 ], [ 25, 69, -1 ], [ 48, 58, -1 ], [ 25, 69, -1 ] ],
        [ [ 8, 91, 1 ], [ 47, 58, -1 ], [ 47, 58 ], [ 8, 91 ] ],
        [ [ 37, 56, -1 ], [ 84, 98, -1 ], undef, undef ],
        [ [ 19, 30 ], [ 22, 65, -1 ], [ 22, 30 ], [ 19, 65 ] ],
        [ [ 8, 45, 1 ], [ 29, 52, -1 ], [ 29, 45 ], [ 8, 52 ] ]
    );
}

use Test::More tests => scalar(@TESTS) * 4;
use JCVI::Range;

foreach my $test (@TESTS) {
    my ( $range1, $range2, $intersection, $union ) =
      map { $_ ? JCVI::Range->new_lus(@$_) : $_ } @$test;
    is_deeply(
        $range1->intersection($range2),
        $intersection,
        sprintf(
            'intersection of %s, %s == %s',
            $range1, $range2, ( $intersection ? $intersection : 'undef' )
        )
    );
    is_deeply( $range2->intersection($range1),
        $intersection, 'converse of previous test' );
    is_deeply(
        $range1->union($range2),
        $union,
        sprintf(
            'union of        %s, %s == %s',
            $range1, $range2, ( $union ? $union : 'undef' )
        )
    );
    is_deeply( $range2->union($range1), $union, 'converse of previous test' );
}
