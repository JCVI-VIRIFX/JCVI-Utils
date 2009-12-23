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
# JCVI::EukDB::Utils - utilities for eukaryotic databases

package JCVI::EukDB::Utils;

use strict;
use warnings;

=head1 NAME

JCVI::EukDB::Utils - utilities for eukaryotic databases

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

=head1 CLASS VARIABLES

=cut

=head1 PUBLIC METHODS

=cut

=head1 UTILITY METHODS

The following methods are useful for converting between database values, such 
  as feature names and pub_loci and for converting between different ways of 
  representing this data, including arrays, files, and temporary tables.

=cut

=head1 GENERIC METHODS

=cut

sub arrayref_to_temp_file {
    my $self = shift;
    my ($arrayref) = @_;

    my $file = File::Temp->new();
    print $file map { "$_\n" } @$arrayref;
    close $file;

    return $file;
}

sub file_to_feature_table {
    my $self = shift;
    my ($file) = @_;

    my $temp = Sybase::TempTable->create( $self->[$_DB_HANDLE],
        'feat_name VARCHAR(25) PRIMARY KEY' );
    my $command =
      sprintf( 'bcp %s in %s -c -r "\n" -t "\t" -U access -P access',
        $temp->name, $file );
    system($command);

    return $temp;
}

sub file_to_pub_locus_table {
    my $self = shift;
    my ($file) = @_;
    
    my $temp = Sybase::TempTable->create( $self->[$_DB_HANDLE], 
        'pub_locus VARCHAR(25) PRIMARY KEY' );
    my $command = 
        sprintf( 'bcp %s in %s -c -r "\n" -t "\t" -U access -P access', 
        $temp->name, $file );
    system($command);
    
    return $temp;
}

sub file_to_assembly_table {
    my $self = shift;
    my ($file) = @_;
    
    my $temp = Sybase::TempTable->create( $self->[$_DB_HANDLE], 
        'asmbl_id INTEGER PRIMARY KEY' );
    my $command = 
        sprintf( 'bcp %s in %s -c -r "\n" -t "\t" -U access -P access', 
        $temp->name, $file );
    system($command);
    
    return $temp;
}

sub temp_table_to_hashref {
    my $self = shift;
    my ($temp) = @_;
    my ( $key, $value );

    my $sth = $self->[$_DB_HANDLE]->prepare_cached( 'SELECT * FROM ' . $temp->name );
    $sth->execute();
    $sth->bind_columns( \( $key, $value ) );

    my %hash;
    while ( $sth->fetch ) {
        push @{ $hash{$key} }, $value;
    }

    return \%hash;
}

=head1 PARENT-FINDING METHODS

=cut

sub feat_names_to_parents {
    my $self       = shift;
    my $temp_table = $self->feat_names_to_parents_temp_table(@_);
    return $self->temp_table_to_hashref($temp_table);
}

sub feat_names_to_parents_temp_table {
    my $self = shift;

    my $feat_arrayref;
    my $feat_tempfile;
    my $feat_filename;
    my $feat_temptable;

    if ( @_ == 0 ) { croak 'No parameters passed' }
    elsif ( @_ > 1 ) { $feat_arrayref = \@_ }
    elsif ( my $ref = ref( $_[0] ) ) {
        if    ( $ref eq 'ARRAY' )             { $feat_arrayref  = $_[0] }
        elsif ( $ref eq 'Sybase::TempTable' ) { $feat_temptable = $_[0] }
        else { die qq{Do not know what to do with reference of type "$ref"} }
    }
    elsif ( -f $_[0] ) { $feat_filename = $_[0] }
    else               { die 'This method does not take a single feat_name' }

    if ($feat_arrayref) {
        return $self->feat_name_small_arrayref_to_parents_temp_table($feat_arrayref)
          if ( @$feat_arrayref <= $SMALL_ARRAY );
        $feat_tempfile = $self->arrayref_to_temp_file($feat_arrayref);
        $feat_filename = $feat_tempfile->filename;
    }
    if ($feat_filename) {
        $feat_temptable = $self->file_to_feature_table($feat_filename);
    }

    return $self->feat_name_temp_table_to_parents_temp_table($feat_temptable);
}

sub feat_name_small_arrayref_to_parents_temp_table {
    my $self = shift;
    my ($feat_names) = @_;

    my $temp = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );

    my $query = q{
        SELECT child_feat AS input_feat, parent_feat AS feat_name
        INTO } . $temp->name . q{
        FROM feat_link
        WHERE child_feat IN ( } . join( ', ', ('?') x @$feat_names ) . q{ )
    };

    $self->[$_DB_HANDLE]->prepare_cached($query)->execute(@$feat_names);

    return $temp;
}

sub feat_name_temp_table_to_parents_temp_table {
    my $self = shift;
    my ($temp1) = @_;

    my $temp2 = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    $self->[$_DB_HANDLE]->prepare_cached(
        q{
            SELECT t.feat_name AS input_feat, l.parent_feat AS feat_name
            INTO } . $temp2->name . q{
            FROM } . $temp1->name . q{ t, feat_link l
            WHERE t.feat_name = l.child_feat
        }
    )->execute();

    return $temp2;
}

=head1 PUB-LOCI FINDING METHODS

Feature names must be for either models or TUs.  Pub loci are only associated 
  with these features and these methods will not check what type of feature 
  names were passed as parameters.

FEAT_NAMES TO PUB LOCI

=cut

sub feat_names_to_pub_loci {
    my $self = shift;
    my $temp_table = $self->feat_names_to_pub_loci_temp_table(@_);
    return $self->temp_table_to_hashref($temp_table);
}

sub feat_names_to_pub_loci_temp_table {
    my $self = shift;
    
    my $feat_arrayref;
    my $feat_tempfile;
    my $feat_filename;
    my $feat_temptable;

    if ( @_ == 0 ) { croak 'No parameters passed' }
    elsif ( @_ > 1 ) { $feat_arrayref = \@_ }
    elsif ( my $ref = ref( $_[0] ) ) {
        if    ( $ref eq 'ARRAY' )             { $feat_arrayref  = $_[0] }
        elsif ( $ref eq 'Sybase::TempTable' ) { $feat_temptable = $_[0] }
        else { die qq{Do not know what to do with reference of type "$ref"} }
    }
    elsif ( -f $_[0] ) { $feat_filename = $_[0] }
    else               { die 'This method does not take a single feat_name.' }

    if ($feat_arrayref) {
        return $self->feat_name_small_arrayref_to_pub_loci_temp_table($feat_arrayref)
          if ( @$feat_arrayref <= $SMALL_ARRAY );
        $feat_tempfile = $self->arrayref_to_temp_file($feat_arrayref);
        $feat_filename = $feat_tempfile->filename;
    }
    if ($feat_filename) {
        $feat_temptable = $self->file_to_feature_table($feat_filename);
    }

    return $self->feat_name_temp_table_to_pub_loci_temp_table($feat_temptable);
}

sub feat_name_small_arrayref_to_pub_loci_temp_table {
    my $self = shift;
    my ($feat_names) = @_;

    my $temp = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );

    my $query = q{
        SELECT feat_name, pub_locus
        INTO } . $temp->name . q{
        FROM ident
        WHERE feat_name IN ( } . join( ', ', ('?') x @$feat_names ) . q{ )
    };

    my $sth = $self->[$_DB_HANDLE]->prepare_cached($query);
    $sth->execute(@$feat_names);

    return $temp;
}

sub feat_name_temp_table_to_pub_loci_temp_table {
    my $self = shift;
    my ($temp1) = @_;

    my $temp2 = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    $self->[$_DB_HANDLE]->prepare_cached(
        q{
            SELECT t.feat_name, i.pub_locus
            INTO } . $temp2->name . q{
            FROM } . $temp1->name . q{ t, ident i
            WHERE t.feat_name = i.feat_name
        }
    )->execute();

    return $temp2;
}

=head1 PUB-LOCI TO FEAT_NAMES

=cut

sub pub_loci_to_feat_names {
    my $self = shift;
    my $temp_table = $self->pub_loci_to_feat_names_temp_table(@_);
    return $self->temp_table_to_hashref($temp_table);
}

sub pub_loci_to_feat_names_temp_table {
    my $self = shift;
    
    my $pub_locus_arrayref;
    my $pub_locus_tempfile;
    my $pub_locus_filename;
    my $pub_locus_temptable;

    if ( @_ == 0 ) { croak 'No parameters passed' }
    elsif ( @_ > 1 ) { $pub_locus_arrayref = \@_ }
    elsif ( my $ref = ref( $_[0] ) ) {
        if    ( $ref eq 'ARRAY' )             { $pub_locus_arrayref  = $_[0] }
        elsif ( $ref eq 'Sybase::TempTable' ) { $pub_locus_temptable = $_[0] }
        else { die qq{Do not know what to do with reference of type "$ref"} }
    }
    elsif ( -f $_[0] ) { $pub_locus_filename = $_[0] }
    else               { die 'This method does not take a single pub_locus.' }

    if ($pub_locus_arrayref) {
        return $self->pub_loci_small_arrayref_to_feat_name_temp_table($pub_locus_arrayref)
          if ( @$pub_locus_arrayref <= $SMALL_ARRAY );
        $pub_locus_tempfile = $self->arrayref_to_temp_file($pub_locus_arrayref);
        $pub_locus_filename = $pub_locus_tempfile->filename;
    }
    if ($pub_locus_filename) {
        $pub_locus_temptable = $self->file_to_pub_locus_table($pub_locus_filename);
    }

    return $self->pub_loci_temp_table_to_feat_name_temp_table($pub_locus_temptable);
}

sub pub_loci_small_arrayref_to_feat_name_temp_table {
    my $self = shift;
    my ($pub_loci) = @_;
    
    my $temp = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    
    my $query = q{
        SELECT pub_locus, feat_name
        INTO } . $temp->name . q{
        FROM ident
        WHERE pub_locus IN ( } . join( ', ', ('?') x @$pub_loci ) . q{ ) 
    };
    
    $self->[$_DB_HANDLE]->prepare_cached($query)->execute(@$pub_loci);
    
    return $temp;
}

sub pub_loci_temp_table_to_feat_name_temp_table {
    my $self = shift;
    my ($temp1) = @_;
    
    my $temp2 = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    $self->[$_DB_HANDLE]->prepare_cached(
        q{
            SELECT t.pub_locus, i.feat_name
            INTO } . $temp2->name . q{
            FROM } . $temp1->name . q{ t, ident i
            WHERE t.pub_locus = i.pub_locus
        }
    )->execute();
    
    return $temp2;
}

=head1 CHILD-FINDING METHODS

=cut

sub feat_names_to_children {
    my $self = shift;
    my $temp_table = $self->feat_names_to_children_temp_table(@_);
    return $self->temp_table_to_hashref($temp_table);
}

sub feat_names_to_children_temp_table {
    my $self = shift;
        
    my $feat_arrayref;
    my $feat_tempfile;
    my $feat_filename;
    my $feat_temptable;

    if ( @_ == 0 ) { croak 'No parameters passed' }
    elsif ( @_ > 1 ) { $feat_arrayref = \@_ }
    elsif ( my $ref = ref( $_[0] ) ) {
        if    ( $ref eq 'ARRAY' )             { $feat_arrayref  = $_[0] }
        elsif ( $ref eq 'Sybase::TempTable' ) { $feat_temptable = $_[0] }
        else { die qq{Do not know what to do with reference of type "$ref"} }
    }
    elsif ( -f $_[0] ) { $feat_filename = $_[0] }
    else               { die 'This method does not take a single feat_name.' }

    if ($feat_arrayref) {
        return $self->feat_name_small_arrayref_to_children_temp_table($feat_arrayref)
          if ( @$feat_arrayref <= $SMALL_ARRAY );
        $feat_tempfile = $self->arrayref_to_temp_file($feat_arrayref);
        $feat_filename = $feat_tempfile->filename;
    }
    if ($feat_filename) {
        $feat_temptable = $self->file_to_feature_table($feat_filename);
    }

    return $self->feat_name_temp_table_to_children_temp_table($feat_temptable);
}

sub feat_name_small_arrayref_to_children_temp_table {
    my $self = shift;
    my ($feat_names) = @_;

    my $temp = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );

    my $query = q{
        SELECT parent_feat AS input_feat, child_feat AS feat_name
        INTO } . $temp->name . q{
        FROM feat_link
        WHERE parent_feat IN ( } . join( ', ', ('?') x @$feat_names ) . q{ )
    };

    $self->[$_DB_HANDLE]->prepare_cached($query)->execute(@$feat_names);

    return $temp;
}

sub feat_name_temp_table_to_children_temp_table {
    my $self = shift;
    my ($temp1) = @_;

    my $temp2 = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    $self->[$_DB_HANDLE]->prepare_cached(
        q{
            SELECT t.feat_name AS input_feat, l.child_feat AS feat_name
            INTO } . $temp2->name . q{
            FROM } . $temp1->name . q{ t, feat_link l
            WHERE t.feat_name = l.parent_feat
        }
    )->execute();

    return $temp2;
}

=head1 ASSEMBLY-FINDING METHODS

=cut

sub assemblies_to_model_feat_names {
    my $self = shift;
    my $temp_table = $self->assemblies_to_model_feat_names_temp_table(@_);
    return $self->temp_table_to_hashref($temp_table);
}

sub assemblies_to_model_feat_names_temp_table {
    my $self = shift;
        
    my $assemblies_arrayref;
    my $assemblies_tempfile;
    my $assemblies_filename;
    my $assemblies_temptable;

    if ( @_ == 0 ) { croak 'No parameters passed' }
    elsif ( @_ > 1 ) { $assemblies_arrayref = \@_ }
    elsif ( my $ref = ref( $_[0] ) ) {
        if    ( $ref eq 'ARRAY' )             { $assemblies_arrayref  = $_[0] }
        elsif ( $ref eq 'Sybase::TempTable' ) { $assemblies_temptable = $_[0] }
        else { die qq{Do not know what to do with reference of type "$ref"} }
    }
    elsif ( -f $_[0] ) { $assemblies_filename = $_[0] }
    else               { die 'This method does not take a single asmbl_id.' }

    if ($assemblies_arrayref) {
        return $self->assemblies_small_arrayref_to_model_feat_names_temp_table($assemblies_arrayref)
          if ( @$assemblies_arrayref <= $SMALL_ARRAY );
        $assemblies_tempfile = $self->arrayref_to_temp_file($assemblies_arrayref);
        $assemblies_filename = $assemblies_tempfile->filename;
    }
    if ($assemblies_filename) {
        $assemblies_temptable = $self->file_to_assembly_table($assemblies_filename);
    }

    return $self->assemblies_temp_table_to_model_feat_names_temp_table($assemblies_temptable);
}

sub assemblies_small_arrayref_to_model_feat_names_temp_table{
    my $self = shift;
    my ($assemblies) = @_;
    
    my $temp = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    
    my $exact_or_not = '=';
    if($self->[$_EV_TYPE] eq '%'){
        $exact_or_not = 'LIKE';
    }
    
    my $query = q{
        SELECT a.asmbl_id, a.feat_name
        INTO } . $temp->name . q{
        FROM asm_feature a, phys_ev p
        WHERE a.feat_name = p.feat_name
        AND p.ev_type } . $exact_or_not . q{ ?
        AND a.feat_type = 'model'
        AND a.asmbl_id IN ( } . join( ', ', ('?') x @$assemblies ) . q{ )
    };
    
    unshift(@$assemblies, $self->[$_EV_TYPE]);
    
    $self->[$_DB_HANDLE]->prepare_cached($query)->execute(@$assemblies);
    
    return $temp;
}

sub assemblies_temp_table_to_model_feat_names_temp_table {
    my $self = shift;
    my ($temp1) = @_;
    
    my $exact_or_not = '=';
    if($self->[$_EV_TYPE] eq '%'){
        $exact_or_not = 'LIKE';
    }
    
    my $temp2 = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    $self->[$_DB_HANDLE]->prepare_cached(
        q{
            SELECT t.asmbl_id, a.feat_name
            INTO } . $temp2->name . q{
            FROM } . $temp1->name . q{ t, asm_feature a, phys_ev p
            WHERE t.asmbl_id = a.asmbl_id
            AND a.feat_type = 'model'
            AND a.feat_name = p.feat_name
            AND p.ev_type } . $exact_or_not . q{ ?
        }
    )->execute($self->[$_EV_TYPE]);
    
    return $temp2;
}

=head1 FEAT_NAMES TO ASSEMBLIES

=cut

sub feat_names_to_assemblies {
    my $self = shift;
    my $temp_table = $self->feat_names_to_assemblies_temp_table(@_);
    return $self->temp_table_to_hashref($temp_table);
}

sub feat_names_to_assemblies_temp_table {
    my $self = shift;
        
    my $feat_arrayref;
    my $feat_tempfile;
    my $feat_filename;
    my $feat_temptable;

    if ( @_ == 0 ) { croak 'No parameters passed' }
    elsif ( @_ > 1 ) { $feat_arrayref = \@_ }
    elsif ( my $ref = ref( $_[0] ) ) {
        if    ( $ref eq 'ARRAY' )             { $feat_arrayref  = $_[0] }
        elsif ( $ref eq 'Sybase::TempTable' ) { $feat_temptable = $_[0] }
        else { die qq{Do not know what to do with reference of type "$ref"} }
    }
    elsif ( -f $_[0] ) { $feat_filename = $_[0] }
    else               { die 'This method does not take a single feat_name.' }

    if ($feat_arrayref) {
        return $self->feat_names_small_arrayref_to_assemblies_temp_table($feat_arrayref)
          if ( @$feat_arrayref <= $SMALL_ARRAY );
        $feat_tempfile = $self->arrayref_to_temp_file($feat_arrayref);
        $feat_filename = $feat_tempfile->filename;
    }
    if ($feat_filename) {
        $feat_temptable = $self->file_to_feature_table($feat_filename);
    }

    return $self->feat_names_temp_table_to_assemblies_temp_table($feat_temptable);
}

sub feat_names_small_arrayref_to_assemblies_temp_table{
    my $self = shift;
    my ($features) = @_;
    
    my $temp = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    
    my $query = q{
        SELECT a.feat_name, a.asmbl_id
        INTO } . $temp->name . q{
        FROM asm_feature a, clone_info c
        WHERE a.asmbl_id = c.asmbl_id
        AND c.is_public = 1
        AND a.feat_name IN ( } . join( ', ', ('?') x @$features ) . q{ )
    };
    
    $self->[$_DB_HANDLE]->prepare_cached($query)->execute(@$features);
}

sub feat_names_temp_table_to_assemblies_temp_table {
    my $self = shift;
    my ($temp1) = @_;
    
    my $temp2 = Sybase::TempTable->reserve( $self->[$_DB_HANDLE] );
    $self->[$_DB_HANDLE]->prepare_cached(
        q{
            SELECT t.feat_name, a.asmbl_id
            INTO } . $temp2->name . q{
            FROM } . $temp1->name . q{ t, asm_feature a, clone_info c
            WHERE t.feat_name = a.feat_name
            AND c.asmbl_id = a.asmbl_id
            AND c.is_public = 1
        }
    )->execute();
    
    return $temp2;
}

{
    my %type_hash = (
        tu          => 'model',
        exon        => 'model',
        cds         => 'exon',
        asmbl_id    => 'model',
    );

    sub convert_to_models {
        my $self = shift;
        my ( $arrayref, $type ) = @_;
        my $hashref;
        my @value_array;

        if($type eq 'model'){
            return $arrayref;
        }
        elsif($type eq 'tu'){
            $hashref = $self->feat_names_to_children($arrayref);
            $type = $type_hash{$type};
        }
        elsif($type eq 'exon' || $type eq 'cds'){
            $hashref = $self->feat_names_to_parents($arrayref);
            $type = $type_hash{$type};
        }
        elsif($type eq 'asmbl_id'){
            $hashref = $self->assemblies_to_model_feat_names($arrayref);
            $type = $type_hash{$type};
        }
        elsif($type eq 'pub_locus'){
            $hashref = $self->pub_loci_to_feat_names($arrayref);
            return $self->pub_loci_feat_names_to_model_feat_names($hashref);
        }
    
        foreach ( values %$hashref ){ push(@value_array, @$_); }
    
        return $self->convert_to_models( \@value_array, $type );
    }
}

#converts a list of feat_names that is potentially a mix of tu and model 
#  feat_names into an arrayref just containing model feat_names
sub pub_loci_feat_names_to_model_feat_names {
    my $self = shift;
    my ($hashref) = @_;
    my $model_arrayref;
    my $tu_arrayref;
    
    foreach my $pub_locus (keys %$hashref){
        ($hashref->{$pub_locus}->[0] =~ m/\d+\.m\d+/)
            ? push(@$model_arrayref, @{$hashref->{$pub_locus}})
            : push(@$tu_arrayref, @{$hashref->{$pub_locus}});
    }
    
    if( @$tu_arrayref > 0 ){
        my $model_hashref;
        $model_hashref = $self->feat_names_to_children($tu_arrayref);
        foreach ( values %$model_hashref ){ push( @$model_arrayref, @$_ ); }
    }
    
    return $model_arrayref;
}

1;