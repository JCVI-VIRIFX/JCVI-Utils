package JCVI::EukDB::Reader::Queries::Assembly;

use strict;
use warnings;

use JCVI::EukDB::Reader::Queries [
    {
        name   => 'asmbl_id',
        plural => 'assemblies'
    },
    'feat_name',
    { table => 'asm_feature', clauses => 'feat_type = ?' },
    [ 'phys_ev p', 'p.feat_name = l.feat_name', 'p.ev_type = ?' ]
];

1;