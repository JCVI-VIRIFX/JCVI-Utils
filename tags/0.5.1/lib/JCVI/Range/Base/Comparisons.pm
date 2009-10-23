# File: Comparisons.pm
# Author: kgalinsk
# Created: Jul 13, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::Range::Base::Comparisons - comparison methods for range objects

package JCVI::Range::Base::Comparisons;

use strict;
use warnings;

use Params::Validate;
use Log::Log4perl qw(:easy);

use overload
  '<=>' => \&spaceship,
  '=='  => \&equal;

=head1 NAME

JCVI::Range::Base::Comparisons - comparison methods for range objects

=head1 SYNOPSIS

    $range1 <=> $range2;
    $range1->spaceship( $range2 );

    $range->contains( $point );

    $range1->outside( $range2 );
    $range1->inside( $range2 );
    $range1->overlap( $range2 );

=head1 DESCRIPTION

These are methods for comparing range objects to points or other range
objects.

=cut

# Variables used for validations
our @LU  = qw(lower upper);
our @LUS = qw(lower upper strand);

=head1 PUBLIC METHODS

=cut

=head2 spaceship

    my @sorted = sort { $a->spaceship($b) } @range;
    my @sorted = sort { $a <=> $b } @range;

Spaceship operator for range. Returns -1, 0 or 1 depending upon the relative
position of two range. Tries to order based upon lower bound, but if those are
the same, then it tries to order based upon upper bound.

=cut

sub spaceship {
    my $self = shift;
    my ($bound) = validate_pos( @_, { can => [qw(lower upper)] }, 0 );
    return ( ( $self->lower <=> $bound->lower )
          || ( $self->upper <=> $bound->upper ) );
}

=head2 contains

    my $bool = $range->contains($point);

Return true if range contain point.

=cut

sub contains {
    my $self = shift;
    my ($location) = validate_pos( @_, { regex => qr/^\d+$/ } );
    return ( ( $self->lower <= $location ) && ( $self->upper >= $location ) );
}

=head2 outside

    my $bool = $a->outside($b);

Returns true if the first bound is outside the second.

=cut

sub outside {
    my $self = shift;
    my ($range) = validate_pos( @_, { can => \@LU } );
    return ( ( $self->lower <= $range->lower )
          && ( $self->upper >= $range->upper ) );
}

=head2 inside

    my $bool = $a->inside($b);

Returns true if the first bound is inside the second.

=cut

sub inside {
    my $self = shift;
    my ($range) = validate_pos( @_, { can => \@LU } );
    return ( ( $self->lower >= $range->lower )
          && ( $self->upper <= $range->upper ) );

}

=head2 equal

    my $bool = $a->equal($b);
    my $bool = ( $a == $b );

Returns true if the range have same endpoints and orientation.

=cut

sub equal {
    my $self = shift;
    my ($range) = validate_pos( @_, { can => \@LUS }, 0 );

    # Return false if a comparison failed
    foreach (@LUS) { return 0 if ( $self->$_ != $range->$_ ) }

    # Return true if all comparisons succeeded
    return 1;
}

=head2 overlap

    my $bool = $a->overlap($b);

Returns true if the two range overlap, false otherwise.

=cut

sub overlap {
    my $self = shift;
    my ($range) = validate_pos( @_, { can => \@LU } );
    return ( ( $self->lower < $range->upper )
          && ( $self->upper > $range->lower ) );
}

1;
