package JCVI::EukDB::Reader::Queries::Aliases;

use strict;
use warnings;

use JCVI::EukDB::Reader::Queries
  [ 'feat_name', { name => 'pub_locus', plural => 'pub_loci' }, 'ident' ],
  [ { name => 'pub_locus', plural => 'pub_loci' }, 'feat_name', 'ident' ];

1;
