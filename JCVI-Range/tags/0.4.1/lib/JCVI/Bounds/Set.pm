# File: Set.pm
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
# JCVI::Bounds::Set - A set of bounds

package JCVI::Bounds::Set;

use strict;
use warnings;

=head1 NAME

JCVI::Bounds::Set - A set of bounds

=cut 

use base qw( JCVI::Bounds::Set::Interface );

use Carp;
use Params::Validate;

use JCVI::Bounds;

=head1 SYNOPSIS

Create an array of bounds which follows the bounds interface.

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

sub _bounds { return $_[0] }

=head1 SET MANIPULATION METHODS

These are the methods that treat the set as an array

=cut

=head2 sort
    
    $set->sort();

Sort bounds in the set

=cut

sub sort {
    my $self  = shift;
    @$self = sort { $a <=> $b } @$self;
}

=head2 push

    $set->push( $bound );
    $set->push( @bounds );

Push bounds onto set. Validate each bound.

=cut

sub push {
    my $self = shift;
    my @exons =
      validate_pos( @_, ( { can => [qw( lower upper strand )] } ) x @_ );
    CORE::push @$self, @exons;
}

1;
