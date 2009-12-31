# File: Queries.pm
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
# JCVI::EukDB::Reader::Queries - generate query methods

package JCVI::EukDB::Reader::Queries;

use strict;
use warnings;

use Params::Validate;

use Sybase::TempTable;

=head1 NAME

JCVI::EukDB::Reader::Queries - generate query methods

=head1 SYNOPSIS

    use JCVI::Queries;
    JCVI::Queries->make_queries( [ $input, $output, $linkage ] );
    JCVI::Queries->make_queries( \@query1_options, \@query2_options, ... );

    use JCVI::Queries \@query1_options, \@query2_options, ...;

=head1 DESCRIPTION

This object will make a set of query methods in your class. It has one publicly
visible method, make_queries, that gets called either through import of
directly. This method will take a set of options presented as an array for a
particular query, and autogenerates the query methods for you.

=cut

=head1 CLASS FUNCTIONS

=cut

=head1 make_queries

=cut

sub make_queries {
    my $class  = shift;
    my $caller = caller();

    my @queries =
      validate_pos( @_, ( { type => Params::Validate::ARRAYREF } ) x @_ );

    foreach my $query (@queries) { $class->_make_query( $caller, @$query ) }
}

*import = \&make_queries;

no strict 'refs';

sub _make_query {
    my $class  = shift;
    my $caller = shift;

    my ( $input, $output, $linkage ) = validate_pos(
        @_,
        { type => Params::Validate::SCALAR | Params::Validate::HASHREF },
        { type => Params::Validate::SCALAR | Params::Validate::HASHREF },
        { type => Params::Validate::SCALAR | Params::Validate::HASHREF },
    );

    $input   = { name  => $input }   unless ( ref($input) );
    $output  = { name  => $output }  unless ( ref($output) );
    $linkage = { table => $linkage } unless ( ref($linkage) );

    my $input_name   = $input->{name};
    my $input_as     = $input->{as} || $input->{name};
    my $input_plural = $input->{plural} || "$input->{name}s";

    my $output_name   = $output->{name};
    my $output_as     = $output->{as} || $output->{name};
    my $output_plural = $output->{plural} || "$output->{name}s";

    my $linkage_table = $linkage->{table};
    my $linkage_column = $linkage->{column} || $input->{name};

    my $tt2tt = sub {
        my $self = shift;
        my ($temp1) = validate_pos( @_, { can => ['name'] } );

        my $dbh = $self->dbh;

        my $temp2 = Sybase::TempTable->reserve($dbh);

        my $temp1_name = $temp1->name;
        my $temp2_name = $temp2->name;

        my $sth = $dbh->prepare(
            qq{
                SELECT  t.$input_name AS $input_as,
                        l.$output_name AS $output_as
                INTO    $temp2_name
                FROM    $temp1_name t, $linkage_table l
                WHERE   t.$input_name = l.$linkage_column
            }
        );
        $sth->execute();
        $sth->finish;

        return $temp2;
    };

    *{"${caller}::${input_plural}_tt2${output_plural}_tt"} = \&$tt2tt;
    *{"${caller}::${input_plural}_temp_table_to_${output_plural}_temp_table"} =
      \&$tt2tt;

    my $arrayref2tt = sub {
        my $self = shift;
        my ($arrayref) =
          validate_pos( @_, { type => Params::Validate::ARRAYREF } );

        my $dbh = $self->dbh;

        my $temp      = Sybase::TempTable->reserve($dbh);
        my $temp_name = $temp->name;

        my $sth = $dbh->prepare(
            qq{
                SELECT  $linkage_column AS $input_as,
                        $output_name AS $output_as
                INTO    $temp_name
                FROM    $linkage_table
                WHERE   $linkage_column IN (}
              . join( ',', ('?') x @$arrayref ) . qq{ )
            }
        );
        $sth->execute(@$arrayref);
        $sth->finish;

        return $temp;
    };

    *{"${caller}::${input_plural}_arrayref2${output_plural}_tt"} = \&$arrayref2tt;
    *{"${caller}::${input_plural}_arrayref_to_${output_plural}_temp_table"} =
      \&$arrayref2tt;
}

1;
