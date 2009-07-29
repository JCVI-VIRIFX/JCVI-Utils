# File: Interface.pm
# Author: Kevin
# Created: Jul 13, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::Bounds::Set::Interface - interface for sets of bounds

package JCVI::Bounds::Set::Interface;

use strict;
use warnings;

=head1 NAME

JCVI::Bounds::Set::Interface - Interface for sets of bounds

=cut

use base qw( JCVI::Bounds::Interface );

use Carp;
use List::Util qw(min max sum);
use Params::Validate;

use JCVI::Bounds;

=head1 ABSTRACT METHODS

=cut

=head2 _bounds

    my $bounds = $set->_bounds();

This is the only method you need to define in your module. It returns the array
of bounds. It won't be modified, so it is ok to return an internal data
structure for speed.

Many methods below will have two definitions; a public one and a private one
prefixed with and underscore ('_'). The public one simply calls the private one
and passes _bounds to it. The reason for this is that _bounds may be expensive
to run for some implementations of the set, and there would be a speed boost
from computing the set of bounds once, but passing it around to several
methods.

=cut

=head1 PUBLIC METHODS

=cut

=head2 bounds

    my $bounds = $set->bounds();

Returns an arrayref of the bounds in the set. This arrayref is different from
the one returned by _bounds because the order of bounds may be changed, but it
won't affect the actual data structure of the set.

=cut

sub bounds { [ @{ shift->_bounds() } ] }

=head1 BOUNDS MAKERS

These functions create new bounds objects

=cut

=head2 simplify

    my $bounds = $set->simplify();

Return a bounds object with the same endpoints and strand as the set.

=cut

sub simplify {
    my $self   = shift;
    my $bounds = $self->_bounds;

    return undef unless (@$bounds);

    my $lower  = $self->_lower($bounds);
    my $upper  = $self->_upper($bounds);
    my $strand = $self->_strand($bounds);

    my $length = $upper - $lower;

    return JCVI::Bounds->new( $lower, $length, $strand );
}

=head2 introns

    my $introns = $set->introns();

Return an arrayref set of bounds which are the introns

=cut

sub introns {
    my $self   = shift;
    my $bounds = $self->_bounds();

    return undef unless (@$bounds);

    @$bounds = sort { $a <=> $b } @$bounds;

    my $introns = [];

    my $a = $bounds->[0];
    for ( my $i = 1 ; $i < @$bounds ; $i++ ) {
        $b = $bounds->[$i];
        push @$introns, JCVI::Bounds->lus( $a->upper, $b->lower );
        $a = $b;
    }

    return $introns;
}

=head1 BOUNDS-LIKE METHODS

These are the methods that allow many of the same functions as bounds uses to
run

=cut

=head2 strand

    my $strand = $set->strand();

Returns the strand.

=cut

sub strand {
    my $self = shift;
    $self->_strand( @_, $self->_bounds );
}

sub _strand {
    my $self = shift;
    my $bounds = pop;

    return undef unless ( defined($bounds) && (@$bounds) );

    # Set bounds
    if (@_) {
        foreach my $bound (@$bounds) {
            $bound->strand(@_);
        }
        
        return @_;
    }

    # Array containing bounds to normalize
    my @normalize;

    # Seed strand
    my $strand = $bounds->[0]->strand;
    push @normalize, $bounds->[0] unless ($strand);

    for ( my $i = 1 ; $i < @$bounds ; $i++ ) {
        my $current = $bounds->[$i]->strand;

        # Where strand = +/-1 (not undef or 0)
        if ($strand) {
            if ($current) {

                # Return undef if two adjacent features are on opposite strands
                # This means that one feature has strand == 1, and the other
                # has strand == -1. A quick/easy test is to see if the product
                # of the two strands is -1
                return undef if ( $strand * $current == -1 );
            }

            else { push @normalize, $bounds->[$i] }

            next;
        }

        # Assign current to strand for cases where strand isn't +/-1
        $strand = $current if ( defined $current );
    }

    # Set the strand of bounds whose strands are 0/undef where others are known
    if ($strand) {
        foreach my $bound (@normalize) {
            $bound->strand($strand)
        }
    }

    return $strand;
}

=head2 lower

    my $lower = $set->lower();

Return/set lower bound

=cut

sub lower {
    my $self = shift;
    $self->_lower( @_, $self->_bounds );
}

sub _lower {
    my $self   = shift;
    my $bounds = pop;

    # Get the lowest bound and return it unless we were given an new one
    my $lowest = min map { $_->lower } @$bounds;

    return $lowest unless (@_);

    # Find the bounds objects whose lower bound matches the lowest bound
    foreach my $bound ( grep { $_->lower == $lowest } @$bounds ) {
        $bound->lower(@_);
    }
}

=head2 upper

    my $upper = $set->upper();

Return upper bound

=cut

sub upper {
    my $self = shift;
    $self->_upper( @_, $self->_bounds );
}

sub _upper {
    my $self   = shift;
    my $bounds = pop;

    # Get the highest bound and return it unless we were given an new one
    my $highest = max map { $_->upper } @$bounds;

    return $highest unless (@_);

    # Find the bounds objects whose upper bound matches the highest bound
    foreach my $bound ( grep { $_->upper == $highest } @$bounds ) {
        $bound->upper(@_);
    }
}

=head1 ADAPTED METHODS

These are methods that are similar to some of the bounds-like ones, but are
relevant only in a set context

=cut

=head2 spliced

Spliced sequence

=cut

sub spliced {
    my $self   = shift;
    my $bounds = $self->_bounds();

    return undef unless (@$bounds);

    # Join the sequence from every bound
    my $sequence = join( '', map { ${ $_->sequence(@_) } } @$bounds );
    return \$sequence;
}

=head2 splength

Spliced length

=cut

sub splength {
    my $self   = shift;
    my $bounds = $self->_bounds();

    return undef unless (@$bounds);

    return sum map { $_->length } @$bounds;
}

1;
