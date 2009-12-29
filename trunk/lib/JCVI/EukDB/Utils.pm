# File: Utils.pm
# Author: kgalinsk
# Created: Dec 23, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::EukDB::Utils - utilities for use by the DAOs

package JCVI::EukDB::Utils;

use strict;
use warnings;

use File::Temp;
use Sybase::TempTable;

=head1 NAME

JCVI::EukDB::Utils - utilities for use by the DAOs 

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

=head1 PUBLIC METHODS

=cut

=head2 GENERIC UTILITIES

=cut

=head3 arrayref_to_temp_file

    my $temp_file = $utils->arrayref_to_temp_file(\@array);
    my $temp_file = $utils->arrayref_to_temp_file($arrayref);

Create a temporary file (provided by File::Temp) given an array of text.

=cut

sub arrayref_to_temp_file {
    my $self = shift;
    my ($arrayref) = @_;

    local $\ = '';

    my $file = File::Temp->new();
    print $file map { "$_\n" } @$arrayref;
    close $file;

    return $file;
}

=head3 file_to_temp_table

    my $temp_table = $utils->file_to_temp_table(
        $column_name,
        $definition,
        $filename
    );

Create a temporary table with one column specified by column_name and
definition and populate it via BCP. Three shortcut methods also provided:

=over

=item my $temp_table = $utils->file_to_feature_table( $filename );

=item my $temp_table = $utils->file_to_pub_locus_table( $filename );

=item my $temp_table = $utils->file_to_assembly_table( $filename );

=back

=cut

sub file_to_temp_table {
    my $self = shift;
    my ( $column, $type, $filename ) = @_;

    my $temp =
      Sybase::TempTable->create( $self->dbh, "$column $type PRIMARY KEY" );
    my $command =
      sprintf( 'bcp %s in %s -c -r "\n" -t "\t" -U access -P access',
        $temp->name, $filename );
    system($command);

    return $temp;
}

sub file_to_feature_table {
    shift->file_to_temp_table( feat_name => 'VARCHAR(25)', @_ );
}

sub file_to_pub_locus_table {
    shift->file_to_temp_table( pub_locus => 'VARCHAR(25)', @_ );
}

sub file_to_assembly_table {
    shift->file_to_temp_table( asmbl_id => 'INTEGER', @_ );
}

=head3 temp_table_to_hashref

    my $hashref = $utils->temp_table_to_hashref( $temp_table );

Dump a two-columned temporary table into a hash of arrays, with the keys of the
hash being the entries in the first column and the arrays populated with the
values of the second column.

=cut

sub temp_table_to_hashref {
    my $self = shift;
    my ($temp) = @_;
    my ( $key, $value );

    my $sth = $self->dbh->prepare_cached( 'SELECT * FROM ' . $temp->name );
    $sth->execute();
    $sth->bind_columns( \( $key, $value ) );

    my %hash;
    while ( $sth->fetch ) {
        push @{ $hash{$key} }, $value;
    }

    return \%hash;
}

1;
