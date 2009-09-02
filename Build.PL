use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'DBIx::JCVI',
    license           => 'perl',
    dist_author       => '"Kevin Galinsky" <"kgalinsky@gmail.com">',
    dist_version_from => 'lib/DBIx/JCVI.pm',
    build_requires    => { 'Test::More' => 0, },
    requires          => {
        'DBI'              => '',
        'DBD::Sybase'      => '',
        'Params::Validate' => '',
        'Term::ReadKey'    => '',
    },
    add_to_cleanup     => ['DBIx-JCVI-*'],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
