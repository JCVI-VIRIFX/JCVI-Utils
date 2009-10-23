# File: Base.pm
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
# JCVI::Range::Base - base class for range objects

package JCVI::Range::Base;

use strict;
use warnings;

use base qw(
  JCVI::Range::Base::Basic
  JCVI::Range::Base::String
  JCVI::Range::Base::Comparisons
  );

use Carp;
use Params::Validate qw(validate validate_pos validate_with);

=head1 NAME

JCVI::Range::Base - base class for range objects

=head1 SYNOPSIS

    package MyRange;
    use base qw( JCVI::Range::Base );
    ...

=head1 DESCRIPTION

This provides the base class for range objects. It is basically a mix-in; a
combination of an interface and methods that can take advantagve of those
abstract methods to provide useful functionality.

=cut

1;
