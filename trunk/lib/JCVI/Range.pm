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
# JCVI::Range - class for boundaries on genetic sequence data

package JCVI::Range;

use strict;
use warnings;

use base qw( JCVI::Range::Interface );

use Carp;
use List::Util qw( min max );
use Params::Validate;

use version; our $VERSION = qv('0.5.0');

=head1 NAME

JCVI::Range - class for boundaries on genetic sequence data

=head1 VERSION

Version 0.5.0

=head1 SYNOPSIS

Create a range object which allows you to convert from 5' and 3' ends to upper
and lower range.

    my $range = JCVI::Range->e53( 52, 143 );

    my $lower  = $range->lower;  # 51
    my $upper  = $range->upper;  # 143
    my $strand = $range->strand; # 1
    my $length = $range->length; # 92
    my $phase  = $range->phase;  # 2

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

    # $range->[0];     # BAD! >:-(
    $range->lower();   # GOOD! :-)

=cut

my $LOWER_INDEX  = 0;
my $LENGTH_INDEX = 1;
my $STRAND_INDEX = 2;

our $INT_REGEX     = qr/^[+-]?\d+$/;
our $POS_INT_REGEX = qr/^\d+$/;
our $STRAND_REGEX  = qr/^[+-]?[01]$/;

=head1 CONSTRUCTORS

=cut

=head2 new

    my $range = JCVI::Range->new( );
    my $range = JCVI::Range->new( $lower );
    my $range = JCVI::Range->new( $lower, $length );
    my $range = JCVI::Range->new( $lower, $length, $strand );

Basic constructor. Pass lower, length and strand.

=cut

sub new {
    my $class = shift;
    my $self  = [
        validate_pos(
            @_,
            ( { default => 0, regex => $POS_INT_REGEX } ) x 2,
            { default => undef, regex => $STRAND_REGEX }
        )
    ];
    bless $self, $class;
}

=head2 e53

    my $range = JCVI::Range->e53($end5, $end3);

Create the class given 5' and 3' end coordinates.

=cut

sub e53 {
    my $class = shift;
    my ( $e5, $e3 ) = validate_pos( @_, ( { regex => $POS_INT_REGEX } ) x 2 );

    return bless( [ --$e5, $e3 - $e5, 1 ],  $class ) if ( $e5 < $e3 );
    return bless( [ --$e3, $e5 - $e3, -1 ], $class ) if ( $e3 < $e5 );
    return bless( [ $e5 - 1, 1 ], $class );
}

=head2 lus

    my $range = JCVI::Range->lus($lower, $upper);
    my $range = JCVI::Range->lus($lower, $upper, $strand);
    
Create the class given lower and upper range, and possibly strand.

=cut

sub lus {
    my $class = shift;
    my $self  = [
        validate_pos(
            @_,
            ( { regex => $POS_INT_REGEX } ) x 2,
            { optional => 1, regex => $STRAND_REGEX }
        )
    ];
    $self->[1] -= $self->[0];
    bless $self, $class;
}

=head2 ul

    $range = JCVI::Range->ul($upper, $length);

Specify upper and length. Useful when using a regular expression to search for
sequencing gaps:

    while ($seq =~ m/(N{20,})/g) {
        push @gaps, JCVI::Range->ul(
            pos($seq),  # pos corresponds to upper bound of regular expression
            length($1)  # $1 is the stretch of Ns found
        );
    }

=cut

sub ul {
    my $class = shift;
    my ( $upper, $length ) =
      validate_pos( @_, ( { regex => $POS_INT_REGEX } ) x 2 );
    $class->new( $upper - $length, $length );
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
    croak 'Lower must be a non-negative integer'
      unless ( $_[0] =~ /$POS_INT_REGEX/ );

    # Adjust the length and lower bound
    $self->_length( $self->upper() - $_[0] );
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

    # new_upper = lower + new_length
    # new_length = new_upper - lower
    $self->_length( $_[0] - $self->lower );
    return $_[0];
}

=head2 length

    $length = $range->length;

Get the length

=cut

sub length { return $_[0][$LENGTH_INDEX] }

# Set the length. The lower bound is the anchor (upper bound changes).
sub _length {
    my $self = shift;

    # Validate the length
    croak 'Length must be a non-negative integer'
      unless ( $_[0] =~ /$POS_INT_REGEX/ );

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
    return undef($self->[$STRAND_INDEX]) unless ( defined $_[0] );

    # Validate strand
    croak 'Value passed to strand must be undef, 0, 1, or -1'
      unless ( $_[0] =~ /$STRAND_REGEX/ );
    return $self->[$STRAND_INDEX] = $_[0] * 1;
}

=head1 COMBINATION METHODS

Returns a new set of range given two range

=cut

=head2 intersection

    my $range = $a->intersection($b);
    my $range = intersection( $a, $b ); 

Returns the intersection of two range. If they don't overlap, return undef.

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
    return $class->new( $lower, $length, $s1 ) if ( $s1 == $s2 );
    return $class->new( $lower, $length );
}

=head1 AUTHOR

"Kevin Galinsky", C<< <"kgalinsk at jcvi.org"> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-jcvi-range at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=JCVI-Range>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc JCVI::Range

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/JCVI-Range>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/JCVI-Range>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=JCVI-Range>

=item * Search CPAN

L<http://search.cpan.org/dist/JCVI-Range>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 "J. Craig Venter Institute", all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
