# $Author$
# $Date$
# $Revision$
# $HeadURL$

package JCVI::Bounds;

use strict;
use warnings;

use version; our $VERSION = qv('0.3.2');

=head1 NAME

JCVI::Bounds - class for boundaries on genetic sequence data

=head1 VERSION

Version 0.3.2

=cut 

use base qw( JCVI::Bounds::Interface );

use Exporter 'import';
our @EXPORT_OK = qw( equal overlap intersection );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use Carp;
use List::Util qw( min max );
use Params::Validate;

my $LOWER_INDEX  = 0;
my $LENGTH_INDEX = 1;
my $STRAND_INDEX = 2;

our $INT_REGEX     = qr/^[+-]?\d+$/;
our $POS_INT_REGEX = qr/^\d+$/;
our $STRAND_REGEX  = qr/^[+-]?[01]$/;

our @LU  = qw(lower upper);
our @LUS = qw(lower upper strand);

my $BOUNDS_WIDTH = 6;

=head1 SYNOPSIS

Create a bounds object which allows you to convert from 5' and 3' ends to upper
and lower bounds.

    my $bounds = JCVI::Bounds->e53( 52, 143 );

    my $lower  = $bounds->lower;  # 51
    my $upper  = $bounds->upper;  # 143
    my $strand = $bounds->strand; # 1
    my $length = $bounds->length; # 92
    my $phase  = $bounds->phase;  # 2

    my $seq_ref = $bounds->sequence(\$sequence); 

    $bounds->lower(86);
    $bounds->upper(134);
    $bounds->strand(-1);
    
    my $end5 = $bounds->end5;     # 134
    my $end3 = $bounds->end3;     # 87
    
=cut

=head1 DESCRIPTION

Store boundary information. Convert from interbase to end5/end3. Compute useful
things like length and phase. Return sequence. Bounds are stored as an
arrayref (DO NOT ACCESS DIRECTLY - FOR DEVELOPERS OF JCVI::Bounds ONLY!!!):

    [ $lower, $length ]
    [ $lower, $length, $strand ]

Entitites are stored in this format to make things easy to validate.

    $lower  >= 0
    $length >= 0
    $strand == -1, 0, 1, or undef
    
The meanings of the strand values are:

    1:      + strand
    -1:     - strand
    0:      . neither strand
    undef:  unknown strand

Please be sure to differentiate between a strand of 0 and undef strand. Use 0
when you know that the object is strandless, and undef when you don't know if
the object is on the + strand, - strand, or is strandless. Seen e53 for an
example of this in use.

=cut

=head1 CONSTRUCTORS

=cut

=head2 new

    my $bounds = JCVI::Bounds->new( );
    my $bounds = JCVI::Bounds->new( $lower );
    my $bounds = JCVI::Bounds->new( $lower, $length );
    my $bounds = JCVI::Bounds->new( $lower, $length, $strand );

Create a new bounds object. The three parameters are optional, but if you
provide a subsequent parameter, a previous one must be supplied as well (i.e.
if strand is provided, then length and lower bound must be provided as well).

    lower:  lower bound, defaults to 0
    length: length of bounds, defaults to 0
    strand: strand of bounds, defaults to undef (unknown)

=cut

sub new {
    my $class = shift;
    my $self  = [
        validate_pos(
            @_,
            ( { default => 0, regex => $POS_INT_REGEX } ) x 2,
            { optional => 1, regex => $STRAND_REGEX }
        )
    ];
    bless $self, $class;
}

=head2 e53

    my $bounds = JCVI::Bounds->e53($end5, $end3);

Create the class given 5' and 3' end coordinates. If end5 == end3, then the
strand is undef.

=cut

sub e53 {
    my $class = shift;
    my ( $e5, $e3 ) = validate_pos( @_, ( { regex => $POS_INT_REGEX } ) x 2 );

    return bless( [ --$e5, $e3 - $e5, 1 ],  $class ) if ( $e5 < $e3 );
    return bless( [ --$e3, $e5 - $e3, -1 ], $class ) if ( $e3 < $e5 );
    return bless( [ $e5 - 1, 1 ], $class );
}

=head2 lus

    my $bounds = JCVI::Bounds->lus($lower, $upper);
    my $bounds = JCVI::Bounds->lus($lower, $upper, $strand);
    
Create the class given lower and upper bounds, and possibly strand.

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

    $bounds = JCVI::Bounds->ul($upper, $length);

Specify upper and length. Useful when using a regular expression to search for
sequencing gaps:

    while ($seq =~ m/(N{20,})/g) {
        push @gaps, JCVI::Bounds->ul(pos($seq), length($1));
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

Get/set the lower bound.

    $lower = $bounds->lower;
    $bounds->lower($lower); 

=cut

sub lower {
    my $self = shift;

    return $self->[$LOWER_INDEX] unless (@_);

    my $new_lower = shift;

    croak 'Lower must be a non-negative integer'
      unless ( $new_lower =~ /$POS_INT_REGEX/ );

    # Need to update the length so upper doesn't change
    #   upper      = lower + length
    #   upper      = old_lower + old_length = new_lower + new_length
    #   new_length = old_lower + old_length - new_lower
    
    my $old_lower = $self->[$LOWER_INDEX];
    $self->_set_length( $old_lower + $self->length() - $new_lower );

    return $self->[$LOWER_INDEX] = $new_lower * 1;
}

=head2 upper

    $upper = $bounds->upper;
    $bounds->upper($upper); 

Get/set the upper bound.

=cut

sub upper {
    my $self = shift;
    
    return $self->lower() + $self->length() unless (@_);
    return $self->length( $_[0] - $self->lower );
}

=head2 length

Get the length.

    $length = $bounds->length;

=cut

sub length {
    return shift->[$LENGTH_INDEX];
}

# Set/validate the length. The lower bound is the anchor (upper bound changes).

sub _set_length {
    my ($self, $length) = @_;

    croak 'Length must be a non-negative integer'
      unless ( $length =~ /$POS_INT_REGEX/ );

    return $self->[$LENGTH_INDEX] = $length;
}


=head2 strand

Get/set the strand. Strand may be undef, 0, 1, or -1.

    $strand = $bounds->strand;
    $bounds->strand($strand);

=cut

sub strand {
    my $self = shift;

    return $self->[$STRAND_INDEX] unless (@_);

    my $strand = shift;

    return delete $self->[$STRAND_INDEX] unless ( defined $strand );

    croak 'Value passed to strand must be undef, 0, 1, or -1'
      unless ( $strand =~ /$STRAND_REGEX/ );

    return $self->[$STRAND_INDEX] = $strand * 1;
}

=head2 phase

    $phase = $bounds->phase();

Get the phase (length % 3).

=cut

sub phase {
    return shift->length % 3;
}

=head1 PUBLIC METHODS

=cut

=head2 extend


    $self = $self->extend( $offset );        # Extend both ends by $offset
    $self = $self->extend( $lower, $upper ); # Extend ends by different amounts

Extend/contract the bounds by the supplied offset(s). To contract, supply a
negative offset.

=cut

sub extend {
    my $self = shift;
    my ( $lower, $upper ) = $self->_validate_extend(@_);

    $self->lower( $self->lower - $lower );
    $self->upper( $self->upper + $upper );

    return $self;
}

# Validate and return offsets. Set upper to lower if lower isn't defined
sub _validate_extend {
    shift;
    my ( $lower, $upper ) = validate_pos(
        @_,
        {
            type  => Params::Validate::SCALAR,
            regex => $INT_REGEX,
        },
        {
            type     => Params::Validate::SCALAR,
            regex    => $INT_REGEX,
            optional => 1
        }
    );

    $upper = $lower unless ( defined $upper );

    return ( $lower, $upper );
}

sub _bool {
    return 1;
}

=head1 COMPARISON METHODS

=head2 contains

    if ( $bounds->contains($point) ) { ... }

Return true if bounds contain point.

=cut

sub contains {
    my $self = shift;
    my ($location) = validate_pos( @_, { regex => qr/^\d+$/ } );
    return ( ( $self->lower <= $location ) && ( $self->upper >= $location ) );
}

=head2 outside

    if ( $a->outside($b) ) { ... }

Returns true if the first bound is outside the second.

=cut

sub outside {
    my ( $a, $b ) = validate_pos( @_, ( { can => \@LU } ) x 2 );
    return ( ( $a->lower <= $b->lower ) && ( $a->upper >= $b->upper ) );
}

=head2 inside

    if ( $a->inside($b) ) { ... }

Returns true if the first bound is inside the second.

=cut

sub inside { outside( reverse(@_) ) }

=head2 equal

    if ( $a->equal($b) ) { ... }
    if ( equal($a, $b) ) { ... }
    if ( $a == $b ) { ... }

Returns true if the bounds have same endpoints and orientation.

=cut

sub equal {

    # Make sure that both objects can run the comparison functions
    my ( $a, $b ) = validate_pos( @_, ( { can => \@LUS } ) x 2, 0 );

    # Return false if a comparison failed
    foreach (@LUS) { return 0 if ( $a->$_ != $b->$_ ) }

    # Return true if all comparisons succeeded
    return 1;
}

=head2 overlap

    if ( $a->overlap($b) ) { ... }
    if ( overlap($a, $b) ) { ... }

Returns true if the two bounds overlap, false otherwise;

=cut

sub overlap {
    my ( $a, $b ) = validate_pos( @_, ( { can => \@LU } ) x 2 );
    return ( ( $a->lower < $b->upper ) && ( $a->upper > $b->lower ) );
}

=head1 COMBINATION METHODS

Returns a new set of bounds given two bounds

=cut

=head2 intersection

    my $bounds = $a->intersection($b);
    my $bounds = intersection( $a, $b ); 

Returns the intersection of two bounds. If they don't overlap, return nothing.

=cut

sub intersection {
    my ( $a, $b ) = validate_pos( @_, ( { can => \@LUS } ) x 2 );

    return unless ( overlap( $a, $b ) );

    my $lower = max( map { $_->lower } $a, $b );
    my $upper = min( map { $_->upper } $a, $b );
    my $length = $upper - $lower;

    my @strands = map { $_->strand } $a, $b;
    return __PACKAGE__->new( $lower, $length, $strands[0] )
      if ( $strands[0] == $strands[1] );
    return __PACKAGE__->new( $lower, $length );
}

=head1 AUTHOR

"Kevin Galinsky", C<< <"kgalinsk at jcvi.org"> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-jcvi-bounds at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=JCVI-Bounds>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc JCVI::Bounds

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/JCVI-Bounds>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/JCVI-Bounds>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=JCVI-Bounds>

=item * Search CPAN

L<http://search.cpan.org/dist/JCVI-Bounds>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 "J. Craig Venter Institute", all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
