# File: Linking.pm
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
# JCVI::EukDB::Reader::Linking - link parent/children features

package JCVI::EukDB::Reader::Queries::Linking;

use strict;
use warnings;

=head1 NAME

JCVI::EukDB::Reader::Linking - link parent/children features

=head1 SYNOPSIS

    my $temp2 = $dao->feat_names_temp_table_to_parents_temp_table( $temp1 );
    my $temp2 = $dao->feat_names_tt2parents_tt( $temp1 );

    my $temp = $dao->feat_names_arrayref_to_parents_temp_table( $feat_names );
    my $temp = $dao->feat_names_arrayref2parents_tt( $feat_names );
    
    my $temp2 = $dao->feat_names_temp_table_to_children_temp_table( $temp1 );
    my $temp2 = $dao->feat_names_tt2children_tt( $temp1 );

    my $temp = $dao->feat_names_arrayref_to_children_temp_table( $feat_names );
    my $temp = $dao->feat_names_arrayref2children_tt( $feat_names );

=cut

use JCVI::EukDB::Reader::Queries [
    { name  => 'feat_name',   as     => 'child' },
    { name  => 'parent_feat', as     => 'feat_name', plural => 'parents' },
    { table => 'feat_link',   column => 'child_feat' }
  ],
  [
    { name  => 'feat_name',  as     => 'parent' },
    { name  => 'child_feat', as     => 'feat_name', plural => 'children' },
    { table => 'feat_link',  column => 'parent_feat' }
  ];

1;
