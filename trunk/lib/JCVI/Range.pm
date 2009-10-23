# File: Range.pm
# Author: kgalinsk
# Created: Apr 15, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::Range - class for ranges on genetic sequence data

package JCVI::Range;

use strict;
use warnings;

use base qw( JCVI::Range::Base );

use Carp;
use List::Util qw( min max );
use Params::Validate;

use version; our $VERSION = qv('0.5.1');

=head1 NAME

JCVI::Range - class for ranges on genetic sequence data

=head1 VERSION

Version 0.5.1

=head1 SYNOPSIS

    my $range = JCVI::Range->new_53( 52, 143 );

    my $lower  = $range->lower;  # 51
    my $upper  = $range->upper;  # 143
    my $strand = $range->strand; # 1
    my $length = $range->length; # 92

    my $seq_ref = $range->sequence(\$sequence); 

    $range->lower(86);
    $range->upper(134);
    $range->strand(-1);
    
    my $end5 = $range->end5;     # 134
    my $end3 = $range->end3;     # 87
    
=head1 DESCRIPTION

Store boundary information. Convert from interbase to end5/end3. Compute useful
things like length and phase. Return sequence. Range are stored as an
arrayref:

    [ $lower, $length, $strand ]

Entitites are stored in this format to make things easy to validate.

    $lower  >= 0
    $length >= 0
    $strand == -1, 0, 1, undef  # See strand method for more info

Do not access array elements directly!

    # $range->[0];     # BAD!
    $range->lower();   # GOOD!

=cut

my $LOWER_INDEX  = 0;
my $LENGTH_INDEX = 1;
my $STRAND_INDEX = 2;

our $NON_NEG_INT_REGEX = qr/^\d+$/;
our $POS_INT_REGEX     = qr/^[1-9]\d*$/;
our $STRAND_REGEX      = qr/^[+-]?[01]$/;

=head1 CONSTRUCTORS

=cut

=head2 new

    my $range = JCVI::Range->new( );
    my $range = JCVI::Range->new( $lower );
    my $range = JCVI::Range->new( $lower, $length );
    my $range = JCVI::Range->new( $lower, $length, $strand );

Basic constructor. Pass lower, length and strand. If not provided, lower and
length default to 0, strand defaults to undef.

=cut

sub new {
    my $class = shift;
    my $self  = [
        validate_pos(
            @_,
            ( { default => 0, regex => $NON_NEG_INT_REGEX } ) x 2,
            { default => undef, regex => $STRAND_REGEX }
        )
    ];
    bless $self, $class;
}

=head2 new_53

    my $range = JCVI::Range->new_53( $end5, $end3 );

Create the class given 5' and 3' end coordinates.

=cut

sub new_53 {
    my $class = shift;
    my ( $e5, $e3 ) = validate_pos( @_, ( { regex => $POS_INT_REGEX } ) x 2 );

    return bless( [ --$e5, $e3 - $e5, 1 ],  $class ) if ( $e5 < $e3 );
    return bless( [ --$e3, $e5 - $e3, -1 ], $class ) if ( $e3 < $e5 );
    return bless( [ $e5 - 1, 1 ], $class );
}

=head2 new_lus

    my $range = JCVI::Range->new_lus( $lower, $upper );
    my $range = JCVI::Range->new_lus( $lower, $upper, $strand );
    
Create the class given lower and upper range, and possibly strand.

=cut

sub new_lus {
    my $class = shift;
    my ( $lower, $upper, $strand ) = validate_pos(
        @_,
        ( { regex => $NON_NEG_INT_REGEX } ) x 2,
        { optional => 1, regex => $STRAND_REGEX }
    );
    my $length = $upper - $lower;
    return bless( [ $lower, $length, $strand ], $class );
}

=head2 new_ul

    my $range = JCVI::Range->new_ul($upper, $length);

Specify upper and length. Useful when using a regular expression to search for
sequencing gaps:

    while ($seq =~ m/(N{20,})/g) {
        push @gaps, JCVI::Range->ul(
            pos($seq),  # pos corresponds to upper bound of regular expression
            length($1)  # $1 is the stretch of Ns found
        );
    }

=cut

sub new_ul {
    my $class = shift;
    my ( $upper, $length ) =
      validate_pos( @_, ( { regex => $NON_NEG_INT_REGEX } ) x 2 );
    $class->new( $upper - $length, $length );
}

=head2 cast

    my $range = JCVI::Range->cast( $range_like_object );

If another object implements the required lower/upper/strand methods defined by
the JCVI::Range interface, you can cast it as a JCVI::Range object. Also, if
your range-like object implements the get_lus method (returning lower, upper
and strand as an arrayref), then cast will use that method instead (useful for
classes where getting this data requires computationally expensive
initialization that can be shared among the different methods).

=cut

sub cast {
    my $class = shift;
    my ($object) = validate_pos( @_, { can => [qw( lower upper strand )] } );

    return $class->new_lus( @{ $object->get_lus } )
      if ( $object->can('get_lus') );
    return $class->new_lus( map { $object->$_ } qw( lower upper strand ) );
}

=head1 ACCESSORS

=cut

=head2 lower

    $lower = $range->lower;
    $range->lower($lower); 

Get/set the lower bound.

=cut

sub lower {
    my $self = shift;
    return $self->[$LOWER_INDEX] unless (@_);

    # Validate the lower bound
    croak 'Lower bound must be a non-negative integer'
      unless ( $_[0] =~ /$NON_NEG_INT_REGEX/ );

    # Adjust the length and lower bound
    $self->_set_length( $self->upper() - $_[0] );
    return $self->[$LOWER_INDEX] = $_[0];
}

=head2 upper

    $upper = $range->upper;
    $range->upper($upper); 

Get/set the upper bound.

=cut

sub upper {
    my $self = shift;

    # upper = lower + length
    return $self->lower() + $self->length() unless (@_);

    # new_upper = lower + new_set_length
    # new_set_length = new_upper - lower
    $self->_set_length( $_[0] - $self->lower );
    return $_[0];
}

=head2 length

    $length = $range->length;

Get the length.

=cut

sub length { return $_[0][$LENGTH_INDEX] }

# Set the length. The lower bound is the anchor (upper bound changes).
sub _set_length {
    my $self = shift;

    # Validate the length
    croak 'Length must be a non-negative integer'
      unless ( $_[0] =~ /$NON_NEG_INT_REGEX/ );

    return $self->[$LENGTH_INDEX] = $_[0] * 1;
}

=head2 strand

    $strand = $range->strand;
    $range->strand($strand);

Get/set the strand. Strand may be undef, 0, 1, or -1. Here are the meanings of
the four values:

    1   - "+" strand
    -1  - "-" strand
    0   - strandless
    undef - unknown

=cut

sub strand {
    my $self = shift;

    return $self->[$STRAND_INDEX] unless (@_);

    # Delete strand if undef passed
    return undef( $self->[$STRAND_INDEX] ) unless ( defined $_[0] );

    # Validate strand
    croak 'Value passed to strand must be undef, 0, 1, or -1'
      unless ( $_[0] =~ /$STRAND_REGEX/ );
    return $self->[$STRAND_INDEX] = $_[0] * 1;
}

=head1 COMBINATION METHODS

Returns a new range given two ranges

=cut

=head2 intersection

    my $range = $a->intersection($b);

Returns the intersection of two ranges. If they don't overlap, return undef.

=cut

sub intersection {
    my $self = shift;

    my ($range) = validate_pos( @_, { can => [qw( lower upper strand )] } );

    return undef unless ( $self->overlap($range) );

    # Get endpoints of intersection
    my $lower = max( map { $_->lower } $self, $range );
    my $upper = min( map { $_->upper } $self, $range );
    my $length = $upper - $lower;

    # Get strands for comparison
    my ( $s1, $s2 ) = map { $_->strand } $self, $range;

    # Create a new object of the same class as self
    my $class = ref($self);
    return $class->new( $lower, $length, $s1 )
      if ( ( defined $s1 ) && ( defined $s2 ) && ( $s1 == $s2 ) );
    return $class->new( $lower, $length );
}

=head2 union

    my $range = $a->union($b);

Returns the union of two ranges. If they don't overlap, return undef.

=cut

sub union {
    my $self = shift;

    my ($range) = validate_pos( @_, { can => [qw( lower upper strand )] } );

    return undef unless ( $self->overlap($range) );

    # Get endpoints of intersection
    my $lower = min( map { $_->lower } $self, $range );
    my $upper = max( map { $_->upper } $self, $range );
    my $length = $upper - $lower;

    # Get strands for comparison
    my ( $s1, $s2 ) = map { $_->strand } $self, $range;

    # Create a new object of the same class as self
    my $class = ref($self);
    return $class->new( $lower, $length, $s1 )
      if ( ( defined $s1 ) && ( defined $s2 ) && ( $s1 == $s2 ) );
    return $class->new( $lower, $length );
}

=head1 AUTHOR

"Kevin Galinsky", C<< <"kgalinsk at jcvi.org"> >>

=head1 BUGS

Please report any bugs or feature requests through JIRA.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc JCVI::Range

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 "J. Craig Venter Institute", all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
