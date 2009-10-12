# File: Interface.pm
# Author: kgalinsk
# Created: Jul 13, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::Range::Interface - interface for range objects

package JCVI::Range::Interface;

use strict;
use warnings;

use base qw(
  JCVI::Range::Interface::Basic
  JCVI::Range::Interface::String
  JCVI::Range::Interface::Comparisons
  );

use Carp;
use Params::Validate qw(validate validate_pos validate_with);

=head1 NAME

JCVI::Range::Interface - interface for range objects

=head1 SYNOPSIS

    package MyRange;
    use base qw( JCVI::Range::Interface );
    ...

=head1 DESCRIPTION

This provides the interface for range objects.

=cut

1;
