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

use overload '""' => \&string, '<=>' => \&relative;

use Carp;
use List::Util qw(reduce min max);
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
    @$self = sort { $a <=> $b } @$self;
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

    my $strand = reduce {
        return 2 if ( $a == 2 );
        return 2 if ( ( $a || 0 ) * ( $b || 0 ) == -1 );
        return $b || $a if ( defined $a );
        return $a || $b;
    }
    map { $_->strand } @$self;

    return $strand if ( $strand != 2 );
    return undef;
}

=head2 lower

    my $lower = $set->lower();

Return lower bound

=cut

# TODO allow setting of bounds

sub lower {
    my $self = shift;
    return min map { $_->lower } @$self;
}

=head2 upper

    my $upper = $set->upper();

Return upper bound

=cut

sub upper {
    my $self = shift;
    return max map { $_->upper } @$self;
}

=head2 length

    my $length = $set->length();

Return distance between upper and lower

=cut

sub length {
    my $self = shift;
    return $self->upper - $self->lower;
}

=head2 end5/end3

These are implemented by stealing from JCVI::Bounds. Set doesn't inherit
from Bounds, but these functions are generic, so no point in reimplenting them.

=cut

{
    no strict 'refs';
    my $package = __PACKAGE__;
    my $bounds  = 'JCVI::Bounds';

    eval "require $bounds;";

    foreach my $sub (
        qw(
        end5
        end3
        _end
        string
        sequence
        _validate_sequence
        outside
        inside
        relative
        )
      )
    {
        *{"${package}::${sub}"} = \&{"${bounds}::${sub}"};
    }
}

1;
