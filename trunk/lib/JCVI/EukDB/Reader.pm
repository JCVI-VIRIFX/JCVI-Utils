# File: Reader.pm
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
# JCVI::EukDB::Reader - reading DAO for eukaryotic databases

package JCVI::EukDB::Reader;

use strict;
use warnings;

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(
    qw(
      dbh

      ev_type

      batch_size
      )
);
__PACKAGE__->mk_accessors(
    qw(
      assemblies
      assemblies_temp_table
      next_batch_index
      deck
      )
);
sub mutator_name_for { return "_set_$_[1]" }

use Carp;
use Params::Validate;
use Sybase::TempTable;

use JCVI::Feature;
use JCVI::Location;

=head1 NAME

JCVI::EukDB::Reader - reading DAO for eukaryotic databases

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

=head1 CLASS VARIABLES

=cut

my $DEFAULT_EV_TYPE    = 'working';
my $DEFAULT_BATCH_SIZE = 1000;

=head1 CONSTRUCTOR

=cut

=head2 new

    my $reader = JCVI::EukDB::Reader->new( $dbh );

=cut

sub new {
    my $class = shift;
    my ( $dbh, @p ) = validate_pos(
        @_,
        { can     => [qw( do prepare_cached )] },
        { default => {}, type => Params::Validate::HASHREF }
    );
    my %p = validate(
        @p,
        {
            ev_type => {
                type    => Params::Validate::SCALAR,
                default => $DEFAULT_EV_TYPE
            },
            batch_size => {
                type    => Params::Validate::HASHREF,
                regex   => qr/^[1-9]\d*$/,
                default => $DEFAULT_BATCH_SIZE
            }
        }
    );
    return $class->SUPER::new( { %p, dbh => $dbh } );
}

=head1 PUBLIC METHODS

=cut

=head1 get_next_gene

    my $gene = $dao->get_next_gene();

Gets the next gene from the deck and restocks the deck of necessary. If there
are no more genes to get, returns nothing.

=cut

sub get_next_gene {
    my $self = shift;
    my $deck = $self->deck();
    
    # Populate the deck if necessary
    if ( ( ! $deck ) || ( ! @$deck ) ) {
        $self->get_next_batch() or return;
        $deck = $self->deck();
    }

    # Shift off the next gene and shift off the assembly if it is done
    my $gene = shift @{ $deck->[0][1] };
    if ( ! @{ $deck->[0][1] }) { shift @$deck }

    return $gene;
}

=head1 get_next_assembly

    my $assembly = $dao->get_next_assembly();

Gets the next assembly from the deck and restocks the deck of necessary. If
there are no more assemblies to get, returns nothing.

=cut

sub get_next_assembly {
    my $self = shift;
    my $deck = $self->deck();

    # Populate the deck if necessary
    if ( ( ! $deck ) || ( ! @$deck ) ) {
        $self->get_next_batch() or return;
        $deck = $self->deck();
    }

    # Shift off the next assembly
    return shift(@$deck);
}

=head1 get_next_batch

    my $batch_TUs = $dao->get_next_batch();

=cut

sub get_next_batch {
    my $self = shift;

    # Get the table of models; function will return undef if we are out
    my $assemblies_temp_table =
      $self->prepare_next_batch_assemblies_temp_table(1)
      or return;
    my $models_temp_table =
      $self->assemblies_temp_table_to_models_temp_table($assemblies_temp_table);
    my $sequences =
      $self->assemblies_temp_table_to_sequences($assemblies_temp_table);

    # Creates table with two columns; child, feat_name
    my $TUs_temp_table =
      $self->feat_names_temp_table_to_parents_temp_table($models_temp_table);

    # Creates table with two columns; parent, feat_name
    my $exons_temp_table =
      $self->feat_names_temp_table_to_children_temp_table($models_temp_table);
    my $CDSs_temp_table =
      $self->feat_names_temp_table_to_children_temp_table($exons_temp_table);

# Expects ( $temp_table, \%options )
# Fetching functional annotation can be enabled, and fetching structural can be disabled
    my $TUs =
      $self->feat_names_temp_table_to_features( $TUs_temp_table,
        { annotation => 1 } );
    my $models = $self->feat_names_temp_table_to_features($models_temp_table);
    my $exons  = $self->feat_names_temp_table_to_features($exons_temp_table);
    my $CDSs   = $self->feat_names_temp_table_to_features($CDSs_temp_table);

# Expects ( $parents, $children, $table )
# Ideally, this method would interrogate the rows of the table passed to determine linkage
    $self->link_parent_children_features( $TUs,    $models, $TUs_temp_table );
    $self->link_parent_children_features( $models, $exons,  $exons_temp_table );
    $self->link_parent_children_features( $exons,  $CDSs,   $CDSs_temp_table );

    # Sort/store the TUs on deck
    my %assemblies;
    foreach my $TU (@$TUs) {
        push @{ $assemblies{ $TU->location->source } }, $TU;
    }
    foreach my $assembly ( values %assemblies ) {
        @$assembly = sort { $a->location <=> $b->location } @$assembly;
    }

    # Store the deck as a hash to make it easier to get the next assembly/gene
    # Each entry of @deck is [ $asmbl_id, $TUs ]
    my @deck =
      map { [ $_, $assemblies{$_}, $sequences->{$_} ] }
      sort { $a <=> $b } keys %assemblies;
    $self->_set_deck( \@deck );

    return $TUs;
}

sub prepare_next_batch_assemblies_temp_table {
    my $self = shift;

    my ( $lower_assembly, $upper_assembly ) =
      $self->get_next_batch_assemblies_ranges(@_);

    my $dbh = $self->dbh;

    my $assemblies_temp_table      = $self->assemblies_temp_table;
    my $assemblies_temp_table_name = $assemblies_temp_table->name;

    my $batch_temp_table      = Sybase::TempTable->reserve($dbh);
    my $batch_temp_table_name = $batch_temp_table->name;

    my $sth = $dbh->prepare_cached(
        qq{
            SELECT *
            INTO   $batch_temp_table_name
            FROM   $assemblies_temp_table_name
            WHERE  asmbl_id >= ?
            AND    asmbl_id <= ?
        }
    );
    $sth->execute( $lower_assembly, $upper_assembly );
    $sth->finish;

    return $batch_temp_table;
}

sub get_next_batch_assemblies_ranges {
    my $self = shift;
    my ($update_next_batch_index) = validate_pos(
        @_,
        {
            type     => Params::Validate::SCALAR | Params::Validate::UNDEF,
            optional => 1
        }
    );

    # Get the necessary object variables
    my $assemblies       = $self->assemblies;
    my $next_batch_index = $self->next_batch_index || 0;
    my $max_batch_size   = $self->batch_size;

    # Prepare the list of assemblies if we don't have it
    unless ($assemblies) {
        $self->prepare_assemblies();
        $assemblies = $self->assemblies;
    }

    # Return nothing if we got everything
    return if ( $next_batch_index > $#$assemblies );

    # Set up initial conditions for iteration
    my $lower_assembly_index = $next_batch_index;
    my $upper_assembly_index = $next_batch_index;
    my $current_batch_size   = $assemblies->[$lower_assembly_index][1];

    # Loop to add next assembly to batch
    while ( $upper_assembly_index < $#$assemblies ) {
        my $next_batch_size = $assemblies->[ $upper_assembly_index + 1 ][1];

        # Break out of loop if next assembly makes the batch too large
        last if ( $current_batch_size + $next_batch_size > $max_batch_size );

        $current_batch_size += $next_batch_size;
        $upper_assembly_index++;
    }

    # Update the index if we were told to do so
    $self->_set_next_batch_index( $upper_assembly_index + 1 )
      if ($update_next_batch_index);

    # Get the assemblies and return them
    my $lower_assembly = $assemblies->[$lower_assembly_index][0];
    my $upper_assembly = $assemblies->[$upper_assembly_index][0];

    return ( $lower_assembly, $upper_assembly );
}

sub prepare_assemblies { shift->prepare_assemblies_from_database(@_) }

sub prepare_assemblies_from_database {
    my $self = shift;

    my $dbh  = $self->dbh;
    my $temp = Sybase::TempTable->reserve($dbh);
    my $name = $temp->name;

    my $sth = $dbh->prepare(
        qq{
            SELECT a.asmbl_id, COUNT(*) AS genes
            INTO   $name
            FROM   assembly a, clone_info c, asm_feature f, phys_ev p
            WHERE  a.asmbl_id  = c.asmbl_id
            AND    a.asmbl_id  = f.asmbl_id
            AND    f.feat_type = 'model'
            AND    f.feat_name = p.feat_name
            AND    p.ev_type = ?
            GROUP BY a.asmbl_id
            ORDER BY a.asmbl_id
        }
    );
    $sth->execute( $self->ev_type );
    $sth->finish;

    $self->_set_assemblies_temp_table($temp);
    $self->_set_assemblies( $dbh->selectall_arrayref("SELECT * FROM $name") );
}

sub assemblies_temp_table_to_models_temp_table {
    my $self = shift;
    my ($assemblies_temp_table) = validate_pos( @_, { can => ['name'] } );

    my $assembly_temp_table_name = $assemblies_temp_table->name;

    my $dbh                    = $self->dbh;
    my $models_temp_table      = Sybase::TempTable->reserve($dbh);
    my $models_temp_table_name = $models_temp_table->name;

    my $sth = $dbh->prepare(
        qq{
            SELECT  f.feat_name
            INTO    $models_temp_table_name
            FROM    $assembly_temp_table_name a, asm_feature f, phys_ev p
            WHERE   f.asmbl_id  = a.asmbl_id 
            AND     f.feat_type = 'model'
            AND     p.feat_name = f.feat_name
            AND     p.ev_type   = ?
        }
    );
    $sth->execute( $self->ev_type );
    $sth->finish;

    return $models_temp_table;
}

{
    my $MAX_ASSEMBLY_SIZE;

    sub assemblies_temp_table_to_sequences {
        my $self = shift;
        my ($assemblies_temp_table) = validate_pos( @_, { can => ['name'] } );

        my $assembly_temp_table_name = $assemblies_temp_table->name;

        my $dbh = $self->dbh;

        unless ($MAX_ASSEMBLY_SIZE) {
            $MAX_ASSEMBLY_SIZE =
              $dbh->selectrow_array('SELECT MAX(length) FROM clone_info');
        }

        $dbh->do("SET TEXTSIZE $MAX_ASSEMBLY_SIZE");

        my %sequences;
        my ( $asmbl_id, $sequence );

        my $sth = $dbh->prepare(
            qq{
                SELECT a.asmbl_id, a.sequence
                FROM   $assembly_temp_table_name t, assembly a
                WHERE  t.asmbl_id = a.asmbl_id
            }
        );
        $sth->execute();
        $sth->bind_columns( \( $asmbl_id, $sequence ) );

        while ( $sth->fetch() ) {
            $sequences{$asmbl_id} = \"$sequence";
        }

        return \%sequences;
    }
}

sub feat_names_temp_table_to_parents_temp_table {
    my $self = shift;
    my ($temp1) = @_;

    my $dbh = $self->dbh;

    my $temp2 = Sybase::TempTable->reserve($dbh);
    $dbh->do(
        q{
            SELECT t.feat_name AS child, l.parent_feat AS feat_name
            INTO } . $temp2->name . q{
            FROM } . $temp1->name . q{ t, feat_link l
            WHERE t.feat_name = l.child_feat
        }
    );

    return $temp2;
}

sub feat_names_temp_table_to_children_temp_table {
    my $self = shift;
    my ($temp1) = @_;

    my $dbh = $self->dbh;

    my $temp2 = Sybase::TempTable->reserve($dbh);
    $dbh->do(
        q{
            SELECT t.feat_name AS parent, l.child_feat AS feat_name
            INTO } . $temp2->name . q{
            FROM } . $temp1->name . q{ t, feat_link l
            WHERE t.feat_name = l.parent_feat
        }
    );

    return $temp2;
}

sub feat_names_temp_table_to_features {
    my $self = shift;
    my ( $temp_table, @p ) = validate_pos(
        @_,
        { can  => ['name'] },
        { type => Params::Validate::HASHREF, default => {} }
    );

    my $temp_table_name = $temp_table->name;

    my $dbh = $self->dbh;

    my ( $feat_name, $asmbl_id, $feat_type, $end5, $end3, $ev_type );
    my $sth = $dbh->prepare(
        qq{
            SELECT  f.feat_name, f.asmbl_id, f.feat_type, f.end5, f.end3, p.ev_type
            FROM    $temp_table_name t, asm_feature f, phys_ev p
            WHERE   t.feat_name = f.feat_name
            AND     t.feat_name *= p.feat_name
        }
    );
    $sth->execute;
    $sth->bind_columns(
        \( $feat_name, $asmbl_id, $feat_type, $end5, $end3, $ev_type ) );

    my @features;
    while ( $sth->fetch ) {
        my $location = JCVI::Location->new_53( $asmbl_id, [ $end5, $end3 ] );

        my $feature = JCVI::Feature->new(
            {
                id         => $feat_name,
                type       => $feat_type,
                provenance => $ev_type,
                location   => $location
            }
        );
        
        push @features, $feature;
    }

    return \@features;
}

sub link_parent_children_features {
    my $self = shift;
    my ( $parents, $children, $temp_table ) = validate_pos(
        @_,
        { type => Params::Validate::ARRAYREF },
        { type => Params::Validate::ARRAYREF },
        { can  => ['name'] }
    );

    my $temp_table_name = $temp_table->name;
    my $sth             = $self->dbh->prepare("SELECT * FROM $temp_table_name");
    $sth->execute();

    my ( $parent_column, $child_column );

    my $columns = $sth->{NAME};

    if ( ( $columns->[0] =~ m/parent/ ) || ( $columns->[1] =~ m/child/ ) ) {
        $sth->bind_columns( \( $parent_column, $child_column ) );
    }
    elsif ( ( $columns->[1] =~ m/parent/ ) || ( $columns->[0] =~ m/child/ ) ) {
        $sth->bind_columns( \( $child_column, $parent_column ) );
    }
    else {
        croak "Unable to use temp table $temp_table_name";
    }

    my %parents_hash  = map { $_->id => $_ } @$parents;
    my %children_hash = map { $_->id => $_ } @$children;

    while ( $sth->fetch ) {
        my $parent = $parents_hash{$parent_column};
        my $child  = $children_hash{$child_column};
        
        next unless ($parent && $child);
        
        push @{ $parent->children }, $child;
        $child->parent($parent);
    }

    return $parents;
}

1;
