use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'JCVI::Range',
    license             => 'perl',
    dist_author         => 'Kevin Galinsky <kgalinsk@jcvi.org>',
    dist_version_from   => 'lib/JCVI/Range.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'JCVI-Range-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
