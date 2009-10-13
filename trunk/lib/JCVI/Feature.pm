# File: Feature.pm
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
# JCVI::Feature - class for biological features

package JCVI::Feature;

use warnings;
use strict;

use Class::Accessor::Fast;
__PACKAGE__->mk_accessors(
    qw(
      id type aliases
      location annotation
      provenance date
      children parent
      )
);

=head1 NAME

JCVI::Feature - class for biological features

=head1 VERSION

Version 0.0.1

=cut

use version; our $VERSION = qv('0.0.1');

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use JCVI::Feature;

    my $foo = JCVI::Feature->new();
    ...

=head1 CONSTRUCTORS

=head2 new

    my $feature = JCVI::Feature->new( \%parameters );
    my $feature = JCVI::Feature->new(
        {
            id          => $id,
            type        => $type,
            aliases     => $aliases,
            location    => $location,
            annotation  => $annotation,
            provenance  => $provenance,
            date        => $date,
            children    => $children,
            parent      => $parent,
        }
    );

This method is provided by Class::Accessor.

=cut

=head1 AUTHOR

"Kevin Galinsky", C<< <"kgalinsk at jcvi.org"> >>

=head1 BUGS

Please report any bugs or feature requests through JIRA.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc JCVI::Feature

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2009 "J. Craig Venter Institute", all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
