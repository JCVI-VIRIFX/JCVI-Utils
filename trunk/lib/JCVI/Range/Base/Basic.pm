# File: Basic.pm
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
# JCVI::Range::Base::Basic - basic range functionality

package JCVI::Range::Base::Basic;

use strict;
use warnings;

use Carp;
use Params::Validate;
use Log::Log4perl qw(:easy);

=head1 NAME

JCVI::Range::Base::Basic - basic range functionality

=head1 SYNOPSIS

    # You define these accessors/mutators
    $range->lower();
    $range->upper();
    $range->strand();
    
    # The following are provided based on the above
    $range->end5();
    $range->end3();

    $range->length();
    
    $range->sequence( \$sequence );

    $range->extend( $offset );
    $range->extend( $offset, $direction );

=head1 DESCRIPTION

This contains the most basic methods for range objects.

=cut

=head1 ABSTRACT METHODS

These accessors/mutators must be defined in your class.

=head2 lower

    my $lower = $range->lower();
    $range->lower($lower);

Get/set lower bound. 

=head2 upper

    my $upper = $range->upper();
    $range->upper($upper);

Get/set upper bound.

=head2 strand

    my $strand = $range->strand();
    $range->strand($strand);

Get/set strand.

=cut

=head1 PUBLIC METHODS

These are mixins that require the abstract methods to function

=cut

=head2 length

    my $length = $range->length();

Return distance between upper and lower range.

=cut

sub length {
    my $self = shift;

    my $lower = $self->lower;
    my $upper = $self->upper;

    return undef unless ( defined($lower) && defined($upper) );

    return $upper - $lower;
}

=head1 5'/3' END CONVERSION

A range object should keep track of upper/lower and strand in some form. The
following methods convert between those values and ends.

=cut

=head2 end5

    $end5 = $range->end5();
    $range->end5($end5);

Get/set 5' end

=cut

sub end5 { shift->_end( 1, @_ ) }

=head2 end3

    $end3 = $range->end3();
    $range->end3($end3);

Get/set 3' end

=cut

sub end3 { shift->_end( -1, @_ ) }

# Does the actual work of figuring out the end
sub _end {
    my $self = shift;

    # $test is "On what strand does this end correspond to the lower bound?"
    my $test = shift;

    my ($end) = validate_pos( @_, { regex => qr/^\d+$/, optional => 1 } );

    # If strand isn't defined or 0:
    # Return the end if end5 = end3 (length == 1)
    # Return undef (since we don't know which is which)
    # Don't allow assignment
    my $strand = $self->strand;
    unless ($strand) {
        my $length = $self->length();

        return undef unless ( ( defined $length ) && ( $length == 1 ) );

        return $self->lower + 1;
    }

    # Get the bound based upon the test
    # For lower range, we want to offset the bound by 1
    my ( $bound, $offset ) = $strand == $test ? ( 'lower', 1 ) : ( 'upper', 0 );

    # Return/set the bound
    return $self->$bound() + $offset unless ( defined $end );
    return $self->$bound( $end - $offset ) + $offset;
}

=head2 sequence

    $sub_ref = $range->sequence($seq_ref);

Extract substring from a sequence reference. Returned as a reference. The same
as:

    substr( $sequence, $range->lower, $range->length );

=cut

sub sequence {
    my $self = shift;

    # Validate that the sequence is a reference and contains the range
    my ($seq_ref) = validate_pos(
        @_,
        {
            type      => Params::Validate::SCALARREF,
            callbacks => {
                'contains range' =>
                  sub { CORE::length( ${ $_[0] } ) >= $self->upper }
            }
        }
    );

    my $lower  = $self->lower;
    my $length = $self->length;

    # Verify that we can get the subsequence
    unless ( defined($lower) && defined($length) ) {
        get_logger( ref $self )
          ->logwarn(
            'Unable to get sequence; lower bound or length not defined');
        return;
    }

    my $substr = substr( $$seq_ref, $lower, $length );
    return \$substr;
}

=head2 extend

    $self = $self->extend( $offset );             # Extend both ends by $offset
    $self = $self->extend( $offset, $direction ); # Specify end to extend

Extend/contract the range by the supplied offset in the specified direction. 
The direction is -1, 0, 1, with -1 meaning to extend the lower bound, 0 to
extend both range (default), and 1 to extend the upper bound. To contract,
supply a negative offset.

=cut

sub extend {
    my $self = shift;
    my ( $offset, $direction ) = validate_pos(
        @_,
        { type => Params::Validate::SCALAR, regex => qr/^[+-]?\d+$/ },
        {
            default => 0,
            type    => Params::Validate::SCALAR,
            regex   => qr/^[+-]?[01]/
        }
    );

    $self->lower( $self->lower - $offset ) unless ($direction == 1);
    $self->upper( $self->upper + $offset ) unless ($direction == -1);

    return $self;
}

1;
