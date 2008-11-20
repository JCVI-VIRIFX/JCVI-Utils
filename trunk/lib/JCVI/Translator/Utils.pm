# JCVI::Translator:Utils
#
# $Author: kgalinsk $
# $Date: 2008-11-20 14:06:40 -0500 (Thu, 20 Nov 2008) $
# $Revision: 24055 $
# $HeadURL: http://isvn.tigr.org/ANNOTATION/DM_Scripts/lib/JCVI/Translator/Utils.pm $

=head1 NAME

package Utils

=head1 SYNOPSES

 use JCVI::Translator::Utils;

 my $translator = new JCVI::Translator::Utils(
                           id => $id,
                           name => $name,
                           table => $table,
                           tableRef => $tableRef
                           );

=head1 DESCRIPTION

See Translator for more info. Utils extends Translator and
adds a few more functions that are normally not used.

=head1 AUTHOR

Kevin Galinsky, <kgalinsk@jcvi.org>

=head1 FUNCTIONS

=over

=cut

package JCVI::Translator::Utils;
use base JCVI::Translator;

use strict;
use warnings;

our $VERSION = '0.2.0';

use Log::Log4perl qw(:easy);
use Params::Validate qw(:all);

sub _loadTable {
    my $self = shift;

    DEBUG('_loadTable called');

    my $error = $self->SUPER::_loadTable(@_);

    return $error if $error;

    ########################################
    # Instantiate regular expressions for
    # later use by getORF/getCDS.

    my $startRegex    = join '|', keys %{ $$self{starts} };
    my $rc_startRegex = join '|', keys %{ $$self{rc_starts} };
    my $stopRegex     = join '|', @{ $$self{reverse}{'*'} };
    my $rc_stopRegex  = join '|', @{ $$self{rc_reverse}{'*'} };

    $$self{startRegex}    = qr/$startRegex/;
    $$self{rc_startRegex} = qr/$rc_startRegex/;
    $$self{stopRegex}     = qr/$stopRegex/;
    $$self{rc_stopRegex}  = qr/$rc_stopRegex/;

    return 0;
}

=item getORF()

=item [$start, $stop] = $translator->getORF($seqRef, $strand);

This will get the longest region between stops and return
the strand, lower and upper bounds, inclusive:

 0 1 2 3 4 5 6 7 8 9 10
  T A A A T C T A A G
  *****       *****
        <--------->

Will return ['+', 3, 9]. You can also specify which strand
you are looking for the ORF to be on.

For ORFs starting at the very beginning of the strand or
trailing off the end, but not in phase with the start or
ends, this method will cut at the last complete codon.

 Eg:

 0 1 2 3 4 5 6 7 8 9 10
  A C G T A G T T T A
                *****
    <--------->

Will return ['-', 1, 7]. The distance between lower and
upper will always be a multiple of 3. This is to make it
clear which frame the ORF is in.

Example:

 $ref = $translator->getORF(\'TAGAAATAG');

Output:

 $ref = [$strand, $lower, $upper]

=cut

sub getORF {
    my $self = shift;

    my ( $seqRef, $strand )
        = validate_pos( @_,
                        { type => SCALARREF },
                        { default => '-+',
                          regex   => qr/^[+-]{1,2}$/
                        }
        );

    DEBUG('getORF called');

    my ( $best_strand, $lower, $upper ) = ( '+', 0, 0 );

    while ( my $cur_strand = chop $strand ) {
        my @lowers = ( 0 .. 2 );
        my $stopRegex
            = $cur_strand eq '+'
            ? $$self{'stopRegex'}
            : $$self{'rc_stopRegex'};

        ########################################
        # Rather than using a regular expression
        # to find regions between stops, it
        # should be  more computationally
        # efficient to find all the stops and
        # compute from there. However, Perl's
        # regular expression engine may be
        # faster than code execution, so this
        # may not be the case

        ########################################
        # A lookahead is used for two reasons:
        # the main one is to get every position
        # within two bases of the end of the
        # sequence, and also to cope with the
        # possibility of overlapping stop
        # codons.

        while (
            $$seqRef =~ /(?=
				($stopRegex)|.{0,2}$
			    )/gx
            )
        {
            my $curUpper = pos $$seqRef;
            my $frame    = $curUpper % 3;

            $curUpper += length $1 if ( $1 && ( $cur_strand eq '+' ) );

            ########################################
            # If the current distance between start
            # and stop is greater than the distance
            # between the stored start and stop,
            # change the stored start and stop to be
            # the current one.

            if ( $upper - $lower < $curUpper - $lowers[$frame] ) {
                $best_strand = $cur_strand;
                $lower       = $lowers[$frame];
                $upper       = $curUpper;
            }

            $lowers[$frame] = $curUpper;
        }

    }

    return [ $best_strand, $lower, $upper ];
}

=item getCDS()

=item [$start, $stop] = $translator->getCDS($seqRef, $strand, $strict);

This will return the strand and boundaries of the longest
CDS.

 0 1 2 3 4 5 6 7 8 9 10
  A T G A A A T A A G
  >>>>>       *****
  <--------------->

Will return ['+', 0, 9].

Strict is a newly added feature which controls how strictly getCDS functions.
There are 3 levels of strictness, enumerated 0, 1 and 2. 2 is the most strict,
and in that mode, a region will only be considered a CDS if both the start and
stop is found. In strict level 1, if a start is found, but no stop is present
before the end of the sequence, the CDS will run until the end of the sequence.
Strict level 0 assumes that start codon is present in each frame just before
the start of the molecule.

Example:

 $ref = $translator->getCDSs(\'ATGAAATAG');
 $ref = $translator->getCDSs(\'ATGAAATAG', '-');

Output:

 $ref = [$strand, $lower, $upper]

=cut

sub getCDS {
    my $self = shift;

    my ( $seqRef, $strand, $strict )
        = validate_pos( @_,
                        { type => SCALARREF },
                        { default => '-+',
                          regex   => qr/^[+-]{1,2}$/
                        },
                        { default => 1,
                          regex   => qr/^[012]$/
                        }
        );

    DEBUG('getCDS called');

    my ( $best_strand, $lower, $upper ) = ( '+', 0, 0 );

    while ( my $cur_strand = chop $strand ) {
        my @lowers;
        my $lowerRegex;
        my $upperRegex;

        if ( $cur_strand eq '+' ) {
            @lowers = ( $strict != 0 ? map {undef} ( 0 .. 2 ) : ( 0 .. 2 ) );
            $lowerRegex = $$self{startRegex};
            $upperRegex = $$self{stopRegex};
        }
        else {
            @lowers = ( $strict == 2 ? map {undef} ( 0 .. 2 ) : ( 0 .. 2 ) );
            $lowerRegex = $$self{rc_stopRegex};
            $upperRegex = $$self{rc_startRegex};
        }

        ########################################
        # Similar to getORF, rather than
        # using a regular expression to find
        # entire regions, instead find
        # individual starts and stops and react
        # accordingly. It captures the starts
        # and stops separately ($1 vs $2) so
        # that it is easy to tell if a start or
        # a stop was matched.
        #
        # If strict mode is at level 2, we don't
        # test CDSs trailing off the end
        # of the molecule

        my $regex = qr/(?=($lowerRegex)|($upperRegex))/;
        $regex = qr/$regex|(?=.{0,2}$)/ unless ( $strict == 2 );

        while ( $$seqRef =~ /$regex/g ) {

            my $position = pos $$seqRef;
            my $frame    = $position % 3;

            ########################################
            # If we match the lower regex we:
            #
            # In the case that we are on the '-'
            # strand, that means we found a stop,
            # so we update the lower bound.
            #
            # Otherwise, we are on the '+' strand,
            # meaning we have found the start, so
            # only set the lower bound if it is not
            # already set (don't want to overwrite
            # the location of a previous start
            # codon).

            if ( $1
                 && (    ( $cur_strand eq '-' )
                      || ( !defined $lowers[$frame] ) )
                )
            {
                $lowers[$frame] = $position;
            }

            ########################################
            # If we don't match the lower regex:
            #
            # If this is the '+' strand, that means
            # that this is a valid stop - either a
            # stop codon or the end of the string.
            # Reset the lower bound in this case.
            #
            # On the '-' strand, we only care if
            # we matched a start. In that case, do
            # the compute and update.
            # Another option would be to mark where
            # the start is, and only do the compute
            # when we find a stop.

            elsif ( ( $cur_strand eq '+' ) || $2 ) {

                # Move on if the lower is unset
                next unless ( defined $lowers[$frame] );

                $position += length $2 if ($2);

                if ( $upper - $lower < $position - $lowers[$frame] ) {
                    $best_strand = $cur_strand;
                    $lower       = $lowers[$frame];
                    $upper       = $position;
                }

                # Reset lower if we found a stop
                undef $lowers[$frame] if ( $cur_strand eq '+' );
            }
        }
    }

    return [ $best_strand, $lower, $upper ];
}

=item translateORF()

=item $pepRef = $translator->translateORF($sequence);

Translates the longest ORF.

Example:

 $pepRef = $translator->translateORF(\'tagtaatag');

=cut

sub translateORF {
    my $self = shift;

    my ( $seqRef, $strand )
        = validate_pos( @_,
                        { type => SCALARREF },
                        { default => '-+',
                          regex   => qr/^[+-]{1,2}$/
                        }
        );

    DEBUG('translateORF called');

    my $boundary = $self->getORF( $seqRef, $strand );
    return
        $self->translate( seqRef => $seqRef,
                          strand => $$boundary[0],
                          lower  => $$boundary[1],
                          upper  => $$boundary[2]
        );
}

=item translateCDS()

=item $peptide = $translator->translateCDS($seqRef);

Translates the longest CDS.

Example:

 $pepRef = $translator->translateCDS(\'atgaaatag');


=cut

sub translateCDS {
    my $self = shift;

    my ( $seqRef, $strand )
        = validate_pos( @_,
                        { type => SCALARREF },
                        { default => '-+',
                          regex   => qr/^[+-]{1,2}$/
                        }
        );

    DEBUG('translateCDS called');

    my $boundary = $self->getCDS( $seqRef, $strand );
    return
        $self->translate( seqRef => $seqRef,
                          strand => $$boundary[0],
                          lower  => $$boundary[1],
                          upper  => $$boundary[2]
        );
}

=item findStarts

=cut

sub findStarts {
    my $self = shift;

    my ( $seqRef, $strand )
        = validate_pos( @_,
                        { type => SCALARREF },
                        { default => '+',
                          regex   => qr/^[+-]{1,2}$/
                        }
        );

    my $startRegex
        = $strand eq '+' ? $$self{startRegex} : $$self{rc_startRegex};

    my @starts;

    while ( $$seqRef =~ /(?=($startRegex))/g ) {
        push @starts, pos $$seqRef;
    }

    return \@starts;
}

=item findStops

=cut

sub findStops {
    my $self = shift;

    my ( $seqRef, $strand )
        = validate_pos( @_,
                        { type => SCALARREF },
                        { default => '+',
                          regex   => qr/^[+-]{1,2}$/
                        }
        );

    my $stopRegex = $strand eq '+' ? $$self{stopRegex} : $$self{rc_stopRegex};

    my @stops;

    while ( $$seqRef =~ /(?=($stopRegex))/g ) {
        push @stops, pos $$seqRef;
    }

    return \@stops;
}

=item startRegex

=cut

sub startRegex {
    my $self = shift;
    my ($strand)
        = validate_pos( @_,
                        { default => '+',
                          regex   => qr/^[+-]{1,2}$/
                        }
        );

    my $prefix = $strand eq '+' ? '' : 'rc_';
    unless ( defined $self->{"${prefix}startRegex"} ) {
        my $regex = join '|', keys %{ $self->{"${prefix}starts"} };
        $self->{"${prefix}startRegex"} = qr/$regex/;
    }
    return $self->{"${prefix}startRegex"};
}

=item stopRegex

=cut

sub stopRegex {
    my $self = shift;
    my ($strand)
        = validate_pos( @_,
                        { default => '+',
                          regex   => qr/^[+-]{1,2}$/
                        }
        );

    my $prefix = $strand eq '+' ? '' : 'rc_';
    unless ( defined $self->{"${prefix}stopRegex"} ) {
        my $regex     = join '|', @{ $$self{"${prefix}reverse"}{'*'} };
        $self->{"${prefix}stopRegex"} = qr/$regex/;
    }
    return $self->{"${prefix}stopRegex"};
}

1;