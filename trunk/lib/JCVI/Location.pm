# File: Location.pm
# Author: kgalinsk
# Created: Oct 13, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::Location - locations on DNA sequences

package JCVI::Location;

use warnings;
use strict;

use base qw( JCVI::Range::Interface );

use Regexp::Common;
use List::Util qw( min max );

=head1 NAME

JCVI::Location - locations on DNA sequences

=head1 VERSION

Version 0.0.1

=cut

use version; our $VERSION = qv('0.0.1');

=head1 SYNOPSIS

Objects of this class represent a range of a DNA sequence. This class stores a
reference to this sequence, the bounds of the range, and the intial phase in
the case of a partial location.

    use JCVI::Location;

    my $location = JCVI::Location->new_53( $source, $end5, $end3 );
    my $location = JCVI::Location->new_53( $source, $end5, $end3, $phase );

    # List of getters/setters
    my $source = $location->source();
    my $lower  = $location->lower();
    my $upper  = $location->upper();
    my $strand = $location->strand();
    my $phase  = $location->phase();
    my $end5   = $location->end5();
    my $end3   = $location->end3();

    # List of just getters
    my $length = $location->length();

See JCVI::Range::Interface for more documentation.

=cut

my $SOURCE_INDEX = 0;
my $LOWER_INDEX  = 1;
my $LENGTH_INDEX = 2;
my $STRAND_INDEX = 3;
my $PHASE_INDEX  = 4;

our $NON_NEG_INT_REGEX = qr/^\d+$/;
our $POS_INT_REGEX     = qr/^[1-9]\d*$/;
our $STRAND_REGEX      = qr/^[+-]?[01]$/;
our $PHASE_REGEX       = qr/^[0-2]$/;

=head1 CONSTRUCTORS

=cut

=head2 new_53

=cut

sub new_53 {
    my $class = shift;
    my ( $source, $e5, $e3, $phase ) = validate_pos(
        @_, 1,
        ( { regex => $POS_INT_REGEX } ) x 2,
        { default => 0, regex => $PHASE_REGEX }
    );

    my $lower = min( $e5, $e3 ) - 1;
    my $length = max( $e5, $e3 ) - $lower;
    my $strand = ( $e3 <=> $e5 ) || undef;

    return bless( [ $source, $lower, $length, $strand, $phase ], $class );
}

=head1 ACCESSORS

=cut

=head2 source

    $source = $location->source();
    $location->source($source);

Get/set the source

=cut

sub source {
    my $self = shift;
    return $self->[$SOURCE_INDEX] unless (@_);
    return $self->[$SOURCE_INDEX] = $_[0];
}

=head2 lower

    $lower = $location->lower();
    $location->lower($lower); 

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

    $upper = $location->upper();
    $location->upper($upper); 

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

    $length = $location->length();

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

    $strand = $location->strand();
    $location->strand($strand);

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

=head2 phase

    my $phase = $location->phase();
    $location->phase( $new_phase );

Get/set the phase. Phase may be 0, 1 or 2. The phase is the offset of the next
frame of the coding region from the start of the location.

=cut

sub phase {
    my $self = shift;

    return $self->[$PHASE_INDEX] unless (@_);

    # Validate the phase
    croak 'Value passed to phase must be 0, 1 or 2'
      unless ( $_[0] =~ /$PHASE_REGEX/ );
    return $self->[$PHASE_REGEX] = $_[0];
}

=head1 AUTHOR

"Kevin Galinsky", C<< <"kgalinsk at jcvi.org"> >>

=head1 BUGS

Please report any bugs or feature requests through JIRA.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc JCVI::Location

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 "J. Craig Venter Institute", all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
