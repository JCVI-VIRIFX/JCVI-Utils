# $Author$
# $Date$
# $Revision$
# $HeadURL$

package JCVI::Bounds::Operations;

use strict;
use warnings;

=head1 NAME

JCVI::Bounds::Operations - Operations that can be performed on bounds/sets

=cut

use Carp;
use Params::Validate qw(validate_with);

use overload '""' => \&_string;

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
      if ( length($seq_ref) < $lower + $length );
    
    my $substr = substr($$seq_ref, $lower, $length);
    return \$substr;
}

1;
