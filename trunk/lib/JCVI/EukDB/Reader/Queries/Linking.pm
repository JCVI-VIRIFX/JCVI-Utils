package JCVI::EukDB::Reader::Queries::Linking;

use strict;
use warnings;

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
