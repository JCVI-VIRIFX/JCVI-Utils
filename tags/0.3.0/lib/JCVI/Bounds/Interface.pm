package JCVI::Bounds::Interface;

use strict;
use warnings;

=head1 NAME

JCVI::Bounds::Interface - interface for bounds objects

=cut

use Carp;
use Params::Validate qw(validate validate_pos validate_with);

use overload '""' => \&_string;

our $INT_REGEX       = qr/^[+-]?\d+$/;
our $POS_0_INT_REGEX = qr/^\d+$/;
our $POS_INT_REGEX   = qr/^\d*[1-9]\d*$/;
our $STRAND_REGEX    = qr/^[+-]?[01]$/;

our @LU  = qw(lower upper);
our @LUS = qw(lower upper strand);

=head1 BASIC METHODS

=cut

=head2 lower

    my $lower = $obj->lower();
    $obj->lower($lower);

Get/set lower bound. Must be defined in your object.

=cut

sub lower { croak 'Lower bound method not defined' }

=head2 upper

    my $upper = $obj->upper();
    $obj->upper($upper);

Get/set upper bound. Must be defined in your object.

=cut

sub upper { croak 'Upper bound method not defined' }

=head2 strand

    my $strand = $obj->strand();
    $obj->strand($strand);

Get/set strand. Must be defined in your object.

=cut

sub strand { croak 'Strand method not defined' }

=head2 length

    my $length = $obj->length();

Return distance between upper and lower bounds.

=cut

sub length {
    my $self = shift;

    my $lower = $self->lower;
    my $upper = $self->upper;

    return undef unless ( defined($lower) && defined($upper) );

    return $upper - $lower;
}

=head2 phase

    $phase = $bounds->phase();

Get the phase (length % 3).

=cut

sub phase {
    my $length = shift->length();
    return undef unless ( defined $length );
    return $length % 3;
}

=head1 5'/3' END CONVERSION

A bounds object should keep track of upper/lower and strand in some form. The
folloing methods convert between those values and ends.

=cut

=head2 end5

    $end5 = $bounds->end5();
    $bounds->end5($end5);

Get/set 5' end

=cut

sub end5 { shift->_end( 1, @_ ) }

=head2 end3

    $end3 = $bounds->end3();
    $bounds->end3($end3);

Get/set 3' end

=cut

sub end3 { shift->_end( -1, @_ ) }

# Does the actual work of figuring out the end
sub _end {
    my $self = shift;

    # $test is "On what strand does the 5' end correspond to the lower bound?"
    my $test = shift;

    my ($end) = validate_pos( @_, { regex => $POS_INT_REGEX, optional => 1 } );

    # If strand isn't defined or 0:
    # Return the end if end5 = end3 (length == 1)
    # Return undef (since we don't know which is which)
    # Don't allow assignment
    my $strand = $self->strand;
    unless ($strand) {
        my $length = $self->length();

        return undef
          unless (
            ( defined $length ) &&
            ( $length = 1 )
          );

        return $self->lower + 1;
    }

    # Get the bound based upon the test
    # For lower bounds, we want to offset the bound by 1
    my ( $bound, $offset ) = $strand == $test ? ( 'lower', 1 ) : ( 'upper', 0 );

    # Return/set the bound
    return $self->$bound() + $offset unless ( defined $end );
    return $self->$bound( $end - $offset ) + $offset;
}

=head1 OPERATIONS

=cut

=head2 string

    print $obj;
    print $obj->string;
    print $obj->string( \%params )

Returns a string for the bounds or set. Valid parameters are:

    method: use one of the string functions below (default is lus)
    width:  padding width for integers

=cut

{

    # Map from (0, 1, -1) to (. + -)
    my @STRAND_MAP = qw( . + - );

    # Default space to give printed integers
    my $INT_WIDTH = 6;

    # Methods for the string
    my %METHOD_MAP = (
        lus => \&lus,
        s53 => \&s53,
        53  => \&s53
    );

    sub string {
        my $obj = shift;
        my %p   = validate_with(
            params => \@_,
            spec   => {
                method => {
                    default   => 'lus',
                    callbacks => {
                        'valid method' => sub { exists $METHOD_MAP{ $_[0] } }
                    }
                }
            },
            allow_extra => 1
        );

        &{ $METHOD_MAP{ $p{method} } }( $obj, @_ );
    }

    sub _string {
        string(shift);
    }

=head2 lus

    $obj->lus();
    $obj->lus( { width => $width } )

Prints the object as [ $lower $upper $strand ]. Pads the output, so it will
look like:

    [ l           u s ]
    [ ll         uu s ]
    [ llllll uuuuuu s ]

=cut

    sub lus {
        my $obj = shift;
        my %p   = validate_with(
            params      => \@_,
            spec        => { width => { default => $INT_WIDTH } },
            allow_extra => 1
        );

        return undef unless ( $obj->can('lower') && $obj->can('upper') );

        my $lower = $obj->lower;
        my $upper = $obj->upper;

        return '[ ? ? ? ]' unless ( defined($lower) && defined($upper) );

        my $strand;
        $strand = '?' unless ( $obj->can('strand') );
        $strand = $obj->strand;
        $strand = defined($strand) ? $STRAND_MAP[$strand] : '?';

        return
          join( ' ', '[', _int( $p{width}, $lower, $upper ), $strand, ']' );
    }

=head2 s53

    $obj->s53();
    $obj->s53( { width => $width } )

Prints the object as <5' $end5 $end3 3'>. Pads the output, so it will look
like:

    <5' 5           3 3'>
    <5' 55         33 3'>
    <5' 555555 333333 3'>

=cut

    sub s53 {
        my $obj = shift;
        my %p   = validate_with(
            params      => \@_,
            spec        => { width => { default => $INT_WIDTH } },
            allow_extra => 1
        );

        my $end5 = $obj->end5;
        my $end3 = $obj->end3;

        return q{<5' ? ? 3'>} unless ( defined($end5) && defined($end3) );

        return join( ' ', q{<5'}, _int( $p{width}, $end5, $end3 ), q{3'>} );
    }

    sub _int {
        my $width = shift;
        return sprintf "%-${width}d %${width}d", @_;
    }
}

=head2 sequence

    $sub_ref = $obj->sequence($seq_ref);

Extract substring from a sequence reference. Returned as a reference. The same
as:

    substr($sequence, $obj->lower, $obj->length);

=cut

sub sequence {
    my $obj     = shift;
    my $seq_ref = shift;

    return undef unless ( $obj->can('lower') && $obj->can('length') );

    my $lower  = $obj->lower;
    my $length = $obj->length;

    return undef unless ( defined($lower) && defined($length) );

    croak 'Object not contained in sequence'
      if ( CORE::length($$seq_ref) < $lower + $length );

    my $substr = substr( $$seq_ref, $lower, $length );
    return \$substr;
}

1;
