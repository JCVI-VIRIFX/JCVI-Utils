# $Author$
# $Date$
# $Revision$
# $HeadURL$

package JCVI::Bounds::Set;

use strict;
use warnings;

=head1 NAME

JCVI::Bounds::Set - A set of bounds

=cut 

use base qw( JCVI::Bounds::Interface );

use Carp;
use List::Util qw(min max sum);
use Params::Validate;

use JCVI::Bounds;

=head1 SYNOPSIS

Create an array of bounds which you can call some of the same methods.

=cut

=head1 CONSTRUCTOR

=head2 new

    my $set = JCVI::Bounds::Set->new();
    my $set = JCVI::Bounds::Set->new( @bounds );

Create a new set and push any bounds provided onto the set

=cut

sub new {
    my $class = shift;
    my $self  = [];
    bless $self, $class;
    $self->push(@_);
    return $self;
}

=head1 BOUNDS MAKERS

These functions create new bounds objects

=cut

=head2 to_bounds

    my $bounds = $set->to_bounds();

Return a bounds object with the same endpoints and strand as the set.

=cut

sub to_bounds {
    my $self = shift;

    return undef unless (@$self);

    my $lower  = $self->lower;
    my $upper  = $self->upper;
    my $length = $upper - $lower;

    return JCVI::Bounds->new( $lower, $length, $self->strand() );
}

=head1 ARRAY BASED METHODS

These are the methods that treat the set as an array

=cut

=head2 sort
    
    $set->sort();

Sort bounds in the set

=cut

sub sort {
    my $self  = shift;
    my $class = ref $self;
    @$self = sort { JCVI::Bounds::relative( $a, $b ) } @$self;
    bless $self, $class;
}

=head2 push

    $set->push( $bound );
    $set->push( @bounds );

Push exons onto group

=cut

sub push {
    my $self = shift;
    my @exons =
      validate_pos( @_, ( { can => [qw( lower upper strand )] } ) x @_ );
    CORE::push @$self, @exons;
}

=head1 BOUNDS-LIKE METHODS

These are the methods that allow many of the same functions as bounds uses to
run

=cut

=head2 strand

    my $strand = $set->strand();

Returns the strand.

=cut

# TODO allow normalization of strands (i.e. if some aren't defined, set)

sub strand {
    my $self = shift;

    return undef unless (@$self);

    my $strand = $self->[0]->strand;
    for ( my $i = 1 ; $i < @$self ; $i++ ) {
        my $current = $self->[$i]->strand;

        if ($strand) {
            if ($current) {

                # Return undef if two adjacent features are on opposite strands
                # This means that one feature has strand == 1, and the other
                # has strand == -1. A quick/easy test is to see if the product
                # of the two strands is -1
                return undef if ( $strand * $current == -1 );
            }

            next;
        }

        # Assign current to strand
        $strand = $current if ( defined $current );
    }

    return $strand;
}

=head2 lower

    my $lower = $set->lower();

Return lower bound

=cut

# TODO allow setting of bounds

sub lower { return min map { $_->lower } @{shift()} }

=head2 upper

    my $upper = $set->upper();

Return upper bound

=cut

sub upper { return max map { $_->upper } @{shift()} }

sub _end {
    my $self = shift;
    return undef unless (@$self);
    $self->SUPER::_end( @_ );
}

=head1 ADAPTED METHODS

These are methods that are similar to some of the bounds-like ones, but are
relevant only in a set context

=cut

=head2 spliced

Spliced sequence

=cut

sub spliced {
    my $self = shift;
    return undef unless (@$self);
    
    # Join the sequence from each seq_ref from calling sequence on every bound
    my $sequence = join( '', map { $$_ } map { $_->sequence(@_) } @$self );
    return \$sequence;
}

=head2 splength

Spliced length

=cut

sub splength {
    my $self = shift;
    return undef unless (@$self);
    return sum map { $_->length } @$self;
}

1;
