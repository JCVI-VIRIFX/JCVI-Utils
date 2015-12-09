use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'JCVI::DNATools',
    AUTHOR              => 'Kevin Galinsky <kgalinsk@jcvi.org>',
    VERSION_FROM        => 'lib/JCVI/DNATools.pm',
    ABSTRACT_FROM       => 'lib/JCVI/DNATools.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'JCVI-DNATools-*' },
);
