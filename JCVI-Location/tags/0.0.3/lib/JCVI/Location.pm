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

use Carp;
use JCVI::Range;

=head1 NAME

JCVI::Location - locations on DNA sequences

=head1 VERSION

Version 0.0.3

=cut

use version; our $VERSION = qv('0.0.3');

=head1 SYNOPSIS

Objects of this class represent a range of a DNA sequence. This class stores a
reference to this sequence, the bounds of the range, and the intial phase in
the case of a partial location.

    use JCVI::Location;

    # See JCVI::Range for a list of constructors
    my $location = JCVI::Location->$new_function( $source, \@params );
    my $location = JCVI::Location->$new_function( $source, \@params, $phase );

    my $location = JCVI::Location->new_53( $source, [ $end5, $end3 ] );
    my $location = JCVI::Location->new_53( $source, [ $end5, $end3 ], $phase );

    # List of getters/setters
    my $source = $location->source();
    my $range  = $location->range();
    my $phase  = $location->phase();
    
    # Getters/setters from JCVI::Range
    my $lower  = $location->lower();
    my $upper  = $location->upper();
    my $strand = $location->strand();
    my $phase  = $location->phase();
    my $end5   = $location->end5();
    my $end3   = $location->end3();
    my $length = $location->length();

See JCVI::Range for more documentation.

=head2 DESCRIPTION

Location is a source, a range and a phase. Locations can be implemented using
any constructor present in the JCVI::Range class; the parameters to that
constructor are passed as an arrayref as the second parameter to location's
constructor. E.g.

    my $range    = JCVI::Range->new_53( $end5, $end3 ); # Range's constructor
    my $location = JCVI::Location->new_53( $source, [ $end5, $end3 ], $phase );

And of JCVI::Range's methods can be accessed directly through location:

    $range->extend( ... );
    $location->extend( ... );

These methods are automatically generated the first time they are called.
=cut

=head1 ACCESSORS

=cut

my $SOURCE_INDEX = 0;
my $RANGE_INDEX  = 1;
my $PHASE_INDEX  = 2;

our $PHASE_REGEX = qr/^\+?[0-2](?:\.0*)$/;

=head2 source

    my $source = $location->source();
    $location->source( $source );

=cut

sub source {
    return $_[0][$SOURCE_INDEX] unless ( @_ > 1 );
    return $_[0][$SOURCE_INDEX] = $_[1];
}

=head2 range

    my $range = $location->range();
    $location->range( $range );

=cut

sub range {
    return $_[0][$RANGE_INDEX] unless ( @_ > 1 );
    return $_[0][$RANGE_INDEX] = $_[1];
}

=head2 phase

    my $phase = $location->phase();
    $location->phase( $phase );

=cut

sub phase {
    return $_[0][$PHASE_INDEX] unless ( @_ > 1 );
    croak "Invalid phase $_[1] (must be one of 0, 1 or 2)"
      unless ( $_[1] =~ $PHASE_REGEX );
    return $_[0][$SOURCE_INDEX] = $_[1] * 1;
}

=head1 AUTOLOADED METHODS

JCVI::Location will autoload methods that access the range's values. This
allows you to access range's methods and functions as though they were
location's. Three methods are loaded on require:

=over

=item lower

=item upper

=item strand

=back

=cut

foreach (qw( lower upper strand )) { __PACKAGE__->_make_method($_) }

our $AUTOLOAD;
# "Magic" code that autogenerates the JCVI::Range methods
sub AUTOLOAD {
    my $self = shift;
    my ($sub_name) = $AUTOLOAD =~ m/(\w+)$/;

    # Create wrapper around a JCVI::Range object method
    if ( my $class = ref($self) ) {
        croak qq{Invalid method "$sub_name"}
          unless ( $self->range->can($sub_name) );
        $class->_make_method($sub_name);
    }

    # Create wrapper around a JCVI::Range constructor
    else {
        croak qq{Invalid constructor "$sub_name"}
          unless ( JCVI::Range->can($sub_name) );
        $self->_make_constructor($sub_name);
    }

    $self->$sub_name(@_);
}

sub _make_method {
    my ( $class, $method ) = @_;
    no strict 'refs';
    *{"${class}::${method}"} = sub { return shift->range->$method(@_) }
}

sub _make_constructor {
    my ( $class, $constructor ) = @_;
    no strict 'refs';
    *{"${class}::${constructor}"} = sub {
        my $class = shift;
        my ( $source, $range_params, $phase ) = @_;

        # Validate phase and create the range object
        if ($phase) {
            croak "Invalid phase $phase (must be one of 0, 1 or 2)"
              unless ( $_[1] =~ $PHASE_REGEX );
        }
        my $range = JCVI::Range->$constructor(@$range_params);

        # Create the location object
        return bless [ $source, $range, $phase ], $class;
    };
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
