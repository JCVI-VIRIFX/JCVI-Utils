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
use JCVI::Bounds::Set;

=head1 METHODS

=cut

=head2 _bounds

    my $bounds = $set->_bounds();

This is the only method you need to define in your module. It returns the array
of bounds. It won't be modified, so it is ok to return an internal data
structure for speed.

=cut

sub _bounds { croak '_bounds method not defined' }

=head2 bounds

    my $bounds = $set->bounds();

Returns an arrayref of the bounds in the set.

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

Return another set of bounds which is just the introns

=cut

sub introns {
    my $self   = shift;
    my $bounds = $self->_bounds();

    return undef unless (@$bounds);

    @$bounds = sort { $a <=> $b } @$bounds;

    my $introns = JCVI::Bounds::Set->new;

    my $a = $bounds->[0];
    for ( my $i = 1 ; $i < @$bounds ; $i++ ) {
        $b = $bounds->[$i];
        $introns->push( JCVI::Bounds->lus( $a->upper, $b->lower ) );
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

# TODO allow normalization of strands (i.e. if some aren't defined, set)

sub strand {
    my $self = shift;
    $self->_strand( @_, $self->_bounds );
}

sub _strand {
    my $bounds = pop;

    return undef unless ( defined($bounds) && (@$bounds) );

    my $strand = $bounds->[0]->strand;
    for ( my $i = 1 ; $i < @$bounds ; $i++ ) {
        my $current = $bounds->[$i]->strand;

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

sub lower {
    my $self = shift;
    $self->_lower( @_, $self->_bounds );
}

sub _lower {
    return min map { $_->lower } @{ pop() };
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
    return max map { $_->upper } @{ pop() };
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
