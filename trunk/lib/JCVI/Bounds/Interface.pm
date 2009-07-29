# File: Interface.pm
# Author: Kevin
# Created: Jul 13, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::Bounds::Interface - interface for bounds objects

package JCVI::Bounds::Interface;

use strict;
use warnings;

use base qw(
  JCVI::Bounds::Interface::Basic
  JCVI::Bounds::Interface::String
  JCVI::Bounds::Interface::Comparisons
  );

use Carp;
use Params::Validate qw(validate validate_pos validate_with);

=head1 NAME

JCVI::Bounds::Interface - interface for bounds objects

=head1 SYNOPSIS

    package MyBounds;
    use base qw( JCVI::Bounds::Interface );
    ...

=head1 DESCRIPTION

This provides the interface for bounds objects.

=cut

1;
