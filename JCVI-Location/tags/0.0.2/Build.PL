use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'JCVI::Location',
    license             => 'perl',
    dist_author         => '"Kevin Galinsky" <"kgalinsk@jcvi.org">',
    dist_version_from   => 'lib/JCVI/Location.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'JCVI-Location-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
