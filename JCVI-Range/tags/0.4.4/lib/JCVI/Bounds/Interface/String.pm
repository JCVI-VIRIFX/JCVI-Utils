# File: String.pm
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
# JCVI::Bounds::Interface::String - methods for printing out bounds objects

package JCVI::Bounds::Interface::String;

use strict;
use warnings;

use Params::Validate qw( validate_with );
use Log::Log4perl qw(:easy);

use overload '""' => \&_string;

=head1 NAME

JCVI::Bounds::Interface::String - methods for printing out bounds objects

=head1 SYNOPSIS

    print $bounds;
    print $bounds->string;
    print $bounds->string_lus;
    print $bounds->string_53;

=head1 DESCRIPTION



=cut

=head1 PUBLIC METHODS

=head2 string

    print $bounds;
    print $bounds->string;
    print $bounds->string( \%params )

Returns a string for the bounds or set. Valid parameters are:

    method: use one of the string functions below (default is lus)
    width:  padding width for integers

=cut

# Map from (0, 1, -1) to (. + -)
my @STRAND_MAP = qw( . + - );

# Default space to give printed integers
my $INT_WIDTH = 6;

# Default string method
my $DEFAULT_METHOD = 'lus';

# Methods for the string
my %METHOD_MAP = (
    lus => \&string_lus,
    s53 => \&string_53,
    53  => \&string_53
);

sub string {
    my $self = shift;
    my %p    = validate_with(
        params => \@_,
        spec   => {
            method => {
                default   => $DEFAULT_METHOD,
                callbacks => {
                    'valid method' => sub { exists $METHOD_MAP{ $_[0] } }
                }
            }
        },
        allow_extra => 1
    );

    &{ $METHOD_MAP{ $p{method} } }( $self, @_ );
}

# Exists so that overloading doesn't freak out string's parameter validation
sub _string {
    string(shift);
}

=head2 default_string_method

    my $method = JCVI::Bounds::Interface::String->default_string_method();
    JCVI::Bounds::Interface::String->default_string_method( $method );
    
    my $method = $bounds->default_string_method();
    $bounds->default_string_method( $method );

Set/get the global default string method.

=cut

sub default_string_method {
    my $class = shift;

    return $DEFAULT_METHOD unless (@_);

    my ($method) = validate_pos(
        @_,
        {
            callbacks => {
                'valid method' => sub { exists $METHOD_MAP{ $_[0] } }
            }
        }
    );

    return $DEFAULT_METHOD = $method;
}

=head2 default_string_integer_width

    my $width = JCVI::Bounds::Interface::String->default_string_integer_width();
    JCVI::Bounds::Interface::String->default_string_integer_width( $width );
    
    my $width = $bounds->default_string_integer_width();
    $bounds->default_string_integer_width( $width );

Set/get the global default integer width.

=cut

sub default_string_integer_width {
    my $class = shift;

    return $INT_WIDTH unless (@_);

    my ($width) = validate_pos( @_, { regex => qr/^\d+$/ } );
    return $INT_WIDTH = $width;
}

=head2 string_lus

    $self->string_lus();
    $self->string_lus( { width => $width } )

Prints the object as [ $lower $upper $strand ]. Pads the output, so it will
look like:

    [ l           u s ]
    [ ll         uu s ]
    [ llllll uuuuuu s ]

=cut

sub string_lus {
    my $self = shift;
    my %p    = validate_with(
        params => \@_,
        spec   => { width => { default => $INT_WIDTH, regex => qr/^\d+$/ } },
        allow_extra => 1
    );

    return undef unless ( $self->can('lower') && $self->can('upper') );

    my $lower = $self->lower;
    my $upper = $self->upper;

    # Return undef if a coordinate isn't defined
    return '[ ? ? ? ]' unless ( defined($lower) && defined($upper) );

    # Get the strand string as +/-/. if it can be determined or ? otherwise
    my $strand;
    $strand = '?' unless ( $self->can('strand') );
    $strand = $self->strand;
    $strand = defined($strand) ? $STRAND_MAP[$strand] : '?';

    return join( ' ', '[', _int( $p{width}, $lower, $upper ), $strand, ']' );
}

=head2 string_53

    $self->string_53();
    $self->string_53( { width => $width } )

Prints the object as <5' $end5 $end3 3'>. Pads the output, so it will look
like:

    <5' 5           3 3'>
    <5' 55         33 3'>
    <5' 555555 333333 3'>

=cut

sub string_53 {
    my $self = shift;
    my %p    = validate_with(
        params => \@_,
        spec   => { width => { default => $INT_WIDTH, regex => qr/^\d+$/ } },
        allow_extra => 1
    );

    my $end5 = $self->end5;
    my $end3 = $self->end3;

    return q{<5' ? ? 3'>} unless ( defined($end5) && defined($end3) );

    return join( ' ', q{<5'}, _int( $p{width}, $end5, $end3 ), q{3'>} );
}

# Return a string with two bounds padded by a width
sub _int {
    my $width = shift;
    return sprintf "%-${width}d %${width}d", @_;
}

1;
