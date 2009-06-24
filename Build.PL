use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'DBIx::SQSHRC',
    license             => 'perl',
    dist_author         => '"Kevin Galinsky" <"kgalinsky@gmail.com">',
    dist_version_from   => 'lib/DBIx/SQSHRC.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'DBIx-SQSHRC-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
