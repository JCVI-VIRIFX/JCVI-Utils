# File: Aliases.pm
# Author: kgalinsk
# Created: Dec 31, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::EukDB::Reader::Aliases - convert aliases

package JCVI::EukDB::Reader::Queries::Aliases;

use strict;
use warnings;

=head1 NAME

JCVI::EukDB::Reader::Aliases - convert aliases

=head1 SYNOPSIS

    my $temp2 = $dao->feat_names_temp_table_to_pub_loci_temp_table( $temp1 );
    my $temp2 = $dao->feat_names_tt2pub_loci_tt( $temp1 );

    my $temp = $dao->feat_names_arrayref_to_pub_loci_temp_table( $feat_names );
    my $temp = $dao->feat_names_arrayref2pub_loci_tt( $feat_names );
    
    my $temp2 = $dao->pub_loci_temp_table_to_feat_names_temp_table( $temp1 );
    my $temp2 = $dao->pub_loci_tt2feat_names_tt( $temp1 );

    my $temp = $dao->pub_loci_arrayref_to_feat_names_temp_table( $pub_loci );
    my $temp = $dao->pub_loci_arrayref2feat_names_tt( $pub_loci );

=cut

use JCVI::EukDB::Reader::Queries
  [ 'feat_name', { name => 'pub_locus', plural => 'pub_loci' }, 'ident' ],
  [ { name => 'pub_locus', plural => 'pub_loci' }, 'feat_name', 'ident' ];

1;
