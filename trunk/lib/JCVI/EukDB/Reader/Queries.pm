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

use Carp;
use Params::Validate;

use Sybase::TempTable;

=head1 NAME

JCVI::EukDB::Reader::Queries - generate query methods

=head1 SYNOPSIS

    use JCVI::Queries;
    JCVI::Queries->make_queries( [ $input, $output, $linkage ] );
    JCVI::Queries->make_queries( [ $input, $output, $linkage, $addl_clauses ] );
    JCVI::Queries->make_queries( \@query1_options, \@query2_options, ... );

    use JCVI::Queries \@query1_options, \@query2_options, ...;

=head1 DESCRIPTION

This object will make a set of query methods in your class. It has one publicly
visible method, make_queries, that gets called either through import of
directly. This method will take a set of options presented as an array for a
particular query, and autogenerates the query methods for you. The query
methods will be named according to the following scheme:

    input_columns_temp_table_to_output_columns_temp_table
    input_columns_tt2output_columns_tt          # shortened version of above
    
    input_columns_arrayref_to_output_columns_temp_table
    input_columns_arrayref2output_columns_tt    # shortened version of above

=cut

=head1 CLASS FUNCTIONS

=cut

=head2 make_queries

    JCVI::Queries->make_queries( [ $input, $output, $linkage ] );
    JCVI::Queries->make_queries( [ $input, $output, $linkage, $addl_clauses ] );
    JCVI::Queries->make_queries( \@query1_options, \@query2_options, ... );

    JCVI::Queries->make_queries(
        [
            {
                name   => $input_name,  # column name to select
                as     => $input_as,    # how it is output
                plural => $input_plural # plural to use in query name
            },
            {
                name   => $output_name,
                as     => $output_as,
                plural => $output_plural
            },
            {
                table  => $linkage_table,  # table we are linking through
                column => $linkage_column, # we are joining input field to 
            }
        ]
    );

Takes the input type (i.e. feat_name), output type (i.e. parent), linkage or 
conversion table (i.e. feat_link or asm_feature), and optional additional 
clauses to customize the operation of the query.

The input, output and linkage can either be scalars or hashrefs; if they are
scalars, then input/output->{name} takes on the value of the scalar passed and
linkage->{table} takes on the value of the linkage scalar. If they are passed
as hashrefs, the name/table values must be passed in.

The "as" parameter is how the field is output and defaults to the same as the
"name" property. For instance, suppose we are linking features to their
parents. The query links through the feat_link table:

    SELECT t.feat_name, l.parent_feat
    INTO   new_temp_table
    FROM   temp_table t, feat_link l
    WHERE  t.feat_name = l.child_feat

We want this query to work recursively, but that won't happen because the
column feat_name in the new temp table is still the old feat_name. What we want
to happen is:

    SELECT t.feat_name AS child, l.parent_feat AS feat_name

The "as" property is what defines how the field is output.

    JCVI::Queries->make_queries(
        [
            { name => 'feat_name',   as => 'child' },
            { name => 'parent_feat', as => 'feat_name' }
            ...
        ]
    );

The "plural" property is what is used to name the function. By default, it is
the "name" property with the letter "s" appended. The above query, without a
"name" parameter would be named
feat_names_temp_table_to_parent_feats_temp_table. We might want the query just
have "parents" instead of "parent_feats", and so we would specify the
"plural" property. Similarly, a query selecting pub_locus from the ident table
should be have "pub_loci" in the name instead of "pub_locuss".

In the above query, "feat_link" is the linkage->{table} property. The "column"
property specifies what column the temp table is being joined against. By
default, this is the same as input->{name}, however, in this case, the linkage
table column name is "child_feat". Thus, the full make_queries call would look
like:

    JCVI::Queries->make_queries(
        [
            { name => 'feat_name',   as => 'child' },
            { name => 'parent_feat', as => 'feat_name', plural => 'parents' },
            { table => 'feat_link', column => 'child_feat' }
        ]
    ); 

The additional clauses should be a hashref structured in the following way:

    #tables stores any additional tables for the query beyond the linkage 
    #  table, and clauses stores additional parts of the WHERE clause beyond 
    #  simply joining on the linkage table
    $addl_clauses = { 
        tables  => [<array_of_table_hashes>]
        clauses => [<array_of_clause_hashes>],
    }
    
    #a table hash stores the name of the additional table, as well as a 
    #  clause hash to tell how to join the new table in the query
    $table_hash = {
        table   => $table_name,
        clauses => [<array_of_clause_hashes>]
    }
    

    JCVI::Queries->make_queries(
        'asmbl_id',
        'feat_name',
        {
            table => 'asm_feature',
            clauses => 'l.feat_type = ?'
        },
        [ 'phys_ev p', 'p.feat_name = l.feat_name', 'p.ev_type = ?' ]
        
    


    
    
    #the clause hash describes how to assemble the additional WHERE clause. 
    #  if both r_col and r_val are defined, it is assumed that a test is 
    #  desired for both the column and the value, and a clause will be 
    #  assembled for both.
    $clause_hash = {
        l_table => $l_table_name,
        l_col   => $l_column_name,
        r_table => $r_table_name,
        r_col   => $r_column_name,
        r_val   => $r_value,
        comp    => [= != LIKE <= >=],  #default: =
        link    => [AND OR]            #default: AND
    }

Methods for data conversion will then be autogenerated to use the queries 
defined by the parameters passed to make_queries.

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

    my ( $input, $output, $linkage, $clauses ) = validate_pos(
        @_,
        { type => Params::Validate::SCALAR | Params::Validate::HASHREF },
        { type => Params::Validate::SCALAR | Params::Validate::HASHREF },
        { type => Params::Validate::SCALAR | Params::Validate::HASHREF },
        { type => Params::Validate::ARRAYREF, default => [] }
    );

    # Make input/output/linkage hashrefs if they are scalars
    $input   = { name  => $input }   unless ( ref($input) );
    $output  = { name  => $output }  unless ( ref($output) );
    $linkage = { table => $linkage } unless ( ref($linkage) );
    $clauses = [$clauses] if ( @$clauses && ( !ref( $clauses->[0] ) ) );

    # Verify that name/table is present in input/output/linkage
    croak 'Input column name must be provided'  unless ( $input->{name} );
    croak 'Output column name must be provided' unless ( $output->{name} );
    croak 'Linkage table must be provided'      unless ( $linkage->{table} );

    # Get parameters and their default values
    my $input_name   = $input->{name};
    my $input_as     = $input->{as} || $input->{name};
    my $input_plural = $input->{plural} || "$input->{name}s";

    my $output_name   = $output->{name};
    my $output_as     = $output->{as} || $output->{name};
    my $output_plural = $output->{plural} || "$output->{name}s";

    my $linkage_table   = $linkage->{table};
    my $linkage_column  = $linkage->{column} || $input->{name};
    my $linkage_clauses = $linkage->{clauses} || [];
    $linkage_clauses = [$linkage_clauses] unless ( ref($linkage_clauses) );

    my @froms  = ("$linkage_table l");
    my @wheres = @$linkage_clauses;

    foreach my $clause (@$clauses) {
        my $table      = $clause->[0];
        my @conditions = @$clause[ 1 .. $#$clause ];

        push @froms,  $table;
        push @wheres, @conditions;
    }

    my $FROM = join( ', ', @froms );
    my $WHERE = join "\n", map { "AND $_" } @wheres;
    my $parameter_count = $WHERE =~ tr/?//;

    #subroutine for converting between temporary tables
    my $tt2tt_name =
      "${input_plural}_temp_table_to_${output_plural}_temp_table";
    my $tt2tt_short = "${input_plural}_tt2${output_plural}_tt";

    my $tt2tt = sub {
        my $self = shift;
        my ( $temp1, @p ) = validate_pos(
            @_,
            { can => ['name'] },
            ( { type => Params::Validate::SCALAR } ) x $parameter_count
        );

        my $dbh = $self->dbh;

        my $temp2 = Sybase::TempTable->reserve($dbh);

        my $temp1_name = $temp1->name;
        my $temp2_name = $temp2->name;

        my $sth = $dbh->prepare(
            qq{
                SELECT  t.$input_name AS $input_as,
                        l.$output_name AS $output_as
                INTO    $temp2_name
                FROM    $temp1_name t, $FROM 
                WHERE   t.$input_name = l.$linkage_column
                $WHERE
            }
        );
        $sth->execute(@p);
        $sth->finish;

        return $temp2;
    };

    *{"${caller}::$tt2tt_name"}  = \&$tt2tt;
    *{"${caller}::$tt2tt_short"} = \&$tt2tt;

    # arrayref to temp table
    my $arrayref2tt_name =
      "${input_plural}_arrayref_to_${output_plural}_temp_table";
    my $arrayref2tt_short = "${input_plural}_arrayref2${output_plural}_tt";

    my $arrayref2tt = sub {
        my $self = shift;
        my ( $arrayref, @p ) = validate_pos(
            @_,
            { type => Params::Validate::ARRAYREF },
            ( { type => Params::Validate::SCALAR } ) x $parameter_count
        );

        my $dbh = $self->dbh;

        my $temp      = Sybase::TempTable->reserve($dbh);
        my $temp_name = $temp->name;

        my $sth = $dbh->prepare(
            qq{
                SELECT  l.$linkage_column AS $input_as,
                        l.$output_name AS $output_as
                INTO    $temp_name
                FROM    $FROM
                WHERE   l.$linkage_column IN ( }
              . join( ',', ('?') x @$arrayref ) . qq{ )
                $WHERE
            }
        );
        $sth->execute( @$arrayref, @p );
        $sth->finish;

        return $temp;
    };

    *{"${caller}::$arrayref2tt_name"}  = \&$arrayref2tt;
    *{"${caller}::$arrayref2tt_short"} = \&$arrayref2tt;

#    #subroutine for converting one type to a temporary table containing the
#    #  target type
#    my $t12t2tt_name  = "${input_plural}_to_${output_plural}_temp_table";
#    my $t12t2tt_short = "${input_plural}2${output_plural}_tt";
#
#    my $type1_to_type2_tt = sub {
#        my $self = shift;
#
#        my $arrayref;
#        my $tempfile;
#        my $filename;
#        my $temptable;
#
#        if ( @_ == 0 ) { Carp::croak 'No parameters passed.'; }
#
#        my $parameter = shift;
#
#        elsif ( my $ref = ref($parameter) ) {
#            if    ( $ref eq 'ARRAY' )             { $arrayref  = $parameter }
#            elsif ( $ref eq 'Sybase::TempTable' ) { $temptable = $parameter }
#            else {
#                die qq{Do not know what to do with reference of type "$ref"};
#            }
#        }
#        elsif ( -f $parameter ) { $filename = $parameter }
#        else { die qq{This method does not take a single '$input'.} }
#
#        if ($arrayref) {
#            return $self->$arrayref2tt_name( $arrayref, @_ )
#              if ( @$arrayref <= $self->small_array );
#            $tempfile = JCVI::EukDB::Utils->arrayref_to_temp_file($arrayref);
#            $filename = $tempfile->filename;
#        }
#        if ($filename) {
#            $temptable = JCVI::EukDB::Utils->file_to_assembly_table($filename);
#        }
#
#        return $self->$tt2tt_name( $temptable, @_ );
#    };
#
#    *{"${caller}::$t12t2tt_name"}  = \&$type1_to_type2_tt;
#    *{"${caller}::$t12t2tt_short"} = \&$type1_to_type2_tt;
#
#    #subroutine for converting one type to a hashref that maps to the target
#    #  type
#    my $t12t2_name  = "${input_plural}_to_${output_plural}";
#    my $t12t2_short = "${input_plural}2${output_plural}";
#
#    my $type1_to_type2 = sub {
#        my $self = shift;
#
#        my $temp_table = $self->$t12t2tt_name(@_);
#        return JCVI::EukDB::Utils->temp_table_to_hashref($temp_table);
#    };
#
#    *{"${caller}::$t12t2_name"}  = \&$type1_to_type2;
#    *{"${caller}::$t12t2_short"} = \&$type1_to_type2;
}

1;
