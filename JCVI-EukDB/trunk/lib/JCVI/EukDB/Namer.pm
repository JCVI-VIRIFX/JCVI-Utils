# File: Namer.pm
# Author: kgalinsk
# Created: Dec 28, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# JCVI::EukDB::Namer - names features to insert

package JCVI::EukDB::Namer;

use strict;
use warnings;

use base 'Class::Accessor::Faster';
__PACKAGE__->mk_ro_accessors(qw( dbh max ));

use Params::Validate;

=head1 NAME

JCVI::EukDB::Namer - names features to insert

=head1 SYNOPSIS

    my $namer = JCVI::EukDB::Namer->new($dbh);
    $namer->name($feature);

    # To prepare the list of max feat names all at once, do one of the following:
    my $namer = JCVI::EukDB::Namer->new($dbh, { get_all => 1 });
    $namer->get_all_max_feat_names();

=head1 DESCRIPTION

This module will handle creating a new feat_name for features being put into
the legacy eukaryotic annotation database.

=cut

=head1 CLASS VARIABLES

=cut

=head2 %TYPE_CONVERSION

Convert standard feat types to database feat types

=cut

my %TYPE_CONVERSION = ( gene => 'TU', transcript => 'model' );

=head2 %VALID_FEAT_TYPES

Feat types supported by this module.

=cut

my %VALID_FEAT_TYPES = map { $_ => 1 } qw( TU model exon CDS );

=head1 PUBLIC METHODS

=cut

=head2 new

    my $namer = JCVI::EukDB::Namer->new($dbh);
    my $namer = JCVI::EukDB::Namer->new( $dbh, \%options );
    my $namer = JCVI::EukDB::Namer->new( $dbh, { get_all => 1 } );

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
            get_all => {
                type     => Params::Validate::SCALAR | Params::Validate::UNDEF,
                optional => 1
            }
        }
    );

    my $self = $class->SUPER::new( { %p, dbh => $dbh, max => {} } );
    $self->get_all_max_feat_name() if ( $p{get_all} );
    return $self;
}

=head2 name

    $namer->name($feature);

=cut

sub name {
    my $self = shift;
    my ($feature) = validate_pos( @_, { can => [qw( id type location )] } );

    my $type     = $feature->type;
    my $asmbl_id = $feature->location->source;

    if ( $TYPE_CONVERSION{$type} ) { $type = $TYPE_CONVERSION{$type} }

    if ( ref $asmbl_id ) {
    }

    my $max = $self->max->{$asmbl_id}{$type};
    unless ( defined($max) ) {
        $max = $self->get_max_feat_name( $type, $asmbl_id );
    }

    $max++;
    $self->max->{$asmbl_id}{$type} = $max;

    $feature->id(
        sprintf( '%d.%s%06d', $asmbl_id, substr( lc($type), 0, 1 ), $max ) );
}

=head2 get_max_feat_name

=cut

sub get_max_feat_name {
    my $self = shift;
    my ( $asmbl_id, $feat_type ) = validate_pos(
        @_,
        { type => Params::Validate::SCALAR, regex => qr/^\d+$/ },
        {
            type      => Params::Validate::SCALAR,
            callbacks => {
                'valid feat_type' => sub { $VALID_FEAT_TYPES{$_} }
            }
        }
    );

    my $sth = $self->dbh->prepare_cached(
        q{
            SELECT  MAX( 
                      CONVERT(
                        INT,
                        SUBSTRING(
                          feat_name,
                          CHARINDEX( '.', feat_name ) + 2,
                          10
                        )
                      )
                    )
            FROM    asm_feature
            WHERE   asmbl_id = ?
            AND     feat_type = ?
        }
    );
    $sth->execute( $asmbl_id, $feat_type );
    my ($max) = $sth->fetchrow_array();
    $sth->finish();

    return $self->max->{$asmbl_id}{$feat_type} ||= $max;
}

=head2 get_all_max_feat_name

=cut

sub get_all_max_feat_name {
    my $self = shift;

    my $sth = $self->dbh->prepare(
        q{
            SELECT  asmbl_id, feat_type,
                    MAX( 
                      CONVERT(
                        INT,
                        SUBSTRING(
                          feat_name,
                          CHARINDEX( '.', feat_name ) + 2,
                          10
                        )
                      )
                    )
            FROM    asm_feature
            WHERE   feat_type IN ( 'TU', 'model', 'exon', 'CDS' )
        }
    );
    $sth->execute();

    my $maxes = $self->max;

    my ( $asmbl_id, $feat_type, $max );
    $sth->bind_columns( \( $asmbl_id, $feat_type, $max ) );
    while ( $sth->fetch() ) {
        $maxes->{$asmbl_id}{$feat_type} ||= $max;
    }

    return $maxes;
}

1;
