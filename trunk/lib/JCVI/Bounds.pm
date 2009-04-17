# $Author$
# $Date$
# $Revision$
# $HeadURL$

package JCVI::Bounds;

use strict;
use warnings;

use version; our $VERSION = qv('0.2.4');

=head1 NAME

JCVI::Bounds - class for boundaries on genetic sequence data

=head1 VERSION

Version 0.2.4

=cut 

use Exporter 'import';
our @EXPORT_OK = qw( equal overlap relative intersection );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use overload
  '=='   => \&equal,
  '<=>'  => \&relative,
  '""'   => \&string,
  'bool' => \&_bool;

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
    
    my @sorted = sort { $a <=> $b } @bounds;

=cut

=head1 DESCRIPTION

Store boundary information. Convert from interbase to end5/end3. Compute useful
things like length and phase. Return sequence. Bounds are stored as an
arrayref:

    [ $lower, $length ]
    [ $lower, $length, $strand ]

Entitites are stored in this format to make things easy to validate.

    $lower  >= 0
    $length >= 0
    $strand == -1, 0, 1, undef

=cut

=head1 CONSTRUCTORS

=cut

=head2 new

    my $bounds = JCVI::Bounds->new( );
    my $bounds = JCVI::Bounds->new( $lower );
    my $bounds = JCVI::Bounds->new( $lower, $length );
    my $bounds = JCVI::Bounds->new( $lower, $length, $strand );

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

Create the class given 5' and 3' end coordinates.

=cut

sub e53 {
    my $class = shift;
    my ( $e5, $e3 ) = validate_pos( @_, ( { regex => $POS_INT_REGEX } ) x 2 );

    return bless( [ --$e5, $e3 - $e5, 1 ],  $class ) if ( $e5 < $e3 );
    return bless( [ --$e3, $e5 - $e3, -1 ], $class ) if ( $e3 < $e5 );
    return bless( [ $e5 - 1, 1 ], $class );
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

    croak 'Lower must be a non-negative integer'
      unless ( $_[0] =~ /$POS_INT_REGEX/ );
    $self->length( $self->upper() - $_[0] );
    return $self->[$LOWER_INDEX] = $_[0];

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

Get/set the length. The lower bound is the anchor (upper bound changes).

    $length = $bounds->length;
    $bounds->length($length);

=cut

sub length {
    my $self = shift;
    return $self->[$LENGTH_INDEX] unless (@_);

    croak 'Length must be a non-negative integer'
      unless ( $_[0] =~ /$POS_INT_REGEX/ );
    return $self->[$LENGTH_INDEX] = $_[0] * 1;
}

=head2 strand

Get/set the strand. Strand may be undef, 0, 1, or -1.

    $strand = $bounds->strand;
    $bounds->strand($strand);

=cut

sub strand {
    my $self = shift;

    return $self->[$STRAND_INDEX] unless (@_);

    return delete $self->[$STRAND_INDEX] unless ( defined $_[0] );

    croak 'Value passed to strand must be undef, 0, 1, or -1'
      unless ( $_[0] =~ /$STRAND_REGEX/ );
    return $self->[$STRAND_INDEX] = $_[0] * 1;
}

=head2 phase

    $phase = $bounds->phase();

Get the phase (length % 3).

=cut

sub phase {
    return shift->length % 3;
}

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
    my $strand = $self->strand;
    unless ($strand) {
        if ( $self->length != 1 ) {
            return undef;
        }
        return $self->lower + 1;
    }

    # Get the bound based upon the test
    # For lower bounds, we want to offset the bound by 1
    my ( $bound, $offset ) = $strand == $test ? ( 'lower', 1 ) : ( 'upper', 0 );

    # Return/set the bound
    return $self->$bound() + $offset unless ( defined $end );
    return $self->$bound( $end - $offset ) + $offset;
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

=head2 sequence

    $bounds_seq_ref = $bounds->sequence($seq_ref);

Extract substring from a sequence reference. Returned as a reference. The same
as:

    substr($sequence, $bounds->lower, $bounds->length);

=cut

sub sequence {
    my $self      = shift;
    my ($seq_ref) = $self->_validate_sequence(@_);
    my $substr    = substr( $$seq_ref, $self->lower, $self->length );
    return \$substr;
}

# Make sure the sequence is a scalarref and that the upper bound is contained
sub _validate_sequence {
    my $self = shift;
    return validate_pos(
        @_,
        {
            type      => Params::Validate::SCALARREF,
            callbacks => {
                'bounds within sequence' => sub {
                    return ( CORE::length( ${ $_[0] } ) >= $self->upper );
                  }
            }
        }
    );
}

=head2 string

    print $bounds->string;
    print $bounds;

Returns a string for the bounds.

=cut

{

    # Map from (0, 1, -1) to (. + -)
    my @STRAND_MAP = qw( . + - );

    sub string {
        my $self   = shift;
        my $strand = $self->strand();
        return
          sprintf q{[ %1s %s %s ] < 5' %s %s 3' >},
          ( defined($strand) ? $STRAND_MAP[$strand] : '?' ),
          map { sprintf "%${BOUNDS_WIDTH}d", $_ }
          map { $self->$_ } qw( lower upper end5 end3 );
    }
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

=head2 relative

    my $relative = $a->relative($b);
    my $relative = relative($a, $b);
    my $relative = $a <=> $b;

 Returns -1, 0 or 1 depending upon the positions of two features. Tries to
 order first based on the lower bound, and if they are equal, tries to order on
 the upper bound. Otherwise, returns 0.

=cut

sub relative {
    my ( $a, $b ) = validate_pos( @_, ( { can => \@LU } ) x 2, 0 );
    return ( $a->lower <=> $b->lower ) || ( $a->upper <=> $b->upper );
}

=head1 COMBINATION METHODS

Returns a new set of bounds given two bounds

=cut

=head2 intersection

    my $bounds = $a->intersection($b);
    my $bounds = intersection( $a, $b ); 

Returns the intersection of two bounds. If they don't overlap, return undef.

=cut

sub intersection {
    my ( $a, $b ) = validate_pos( @_, ( { can => \@LUS } ) x 2 );

    return undef unless ( overlap( $a, $b ) );

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
