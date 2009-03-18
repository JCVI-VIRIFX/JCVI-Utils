use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'JCVI::AATools',
    AUTHOR              => 'Kevin Galinsky <kgalinsk@jcvi.org>',
    VERSION_FROM        => 'lib/JCVI/AATools.pm',
    ABSTRACT_FROM       => 'lib/JCVI/AATools.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'JCVI-AATools-*' },
);
