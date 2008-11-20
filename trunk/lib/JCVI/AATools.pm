# AATools
#
# $Author: kgalinsk $
# $Date: 2008-11-14 10:35:59 -0500 (Fri, 14 Nov 2008) $
# $Revision: 23931 $
# $HeadURL: http://isvn.tigr.org/ANNOTATION/DM_Scripts/lib/JCVI/AATools.pm $

=head1 NAME

JCVI::AATools - JCVI Basic Amino Acid tools

=head1 SYNOPSES

 use JCVI::AATools qw(:all)

=head1 DESCRIPTION

Provides a set of functions and predefined variables which
are handy when working with Amino Acids.

=head1 AUTHOR

Kevin Galinsky, <kgalinsk@jcvi.org>

=cut

package JCVI::AATools;

use strict;
use warnings;

our $VERSION = '0.1.0';

use Exporter 'import';
our %EXPORT_TAGS = (
    all => [
        qw(%ambiguousForward
            %ambiguousMap
            %aaAbbrev

            $aas
            $aaMatch
            $aaFail
            $strictAAs
            $strictMatch
            $strictFail
            $ambigs
            $ambigMatch
            $ambigFail)
    ],

    funcs => [qw()]
);

our @EXPORT_OK = @{ $EXPORT_TAGS{all} };

=head1 VARIABLES

=over

=cut

=item Ambiguous Mappings

Two ambiguous mapping hashes. One maps from the amino acid
forward to the possible ambiguous amino acid, and one is a
map of what each ambiguous amino acid means.

=cut

our %ambiguousForward = ( A => 'B',
                          B => 'B',
                          D => 'B',
                          I => 'J',
                          J => 'J',
                          L => 'J',
                          E => 'Z',
                          Q => 'Z',
                          Z => 'Z'
);

our %ambiguousMap = ( B => [ 'A', 'D' ],
                      J => [ 'I', 'L' ],
                      Z => [ 'E', 'Q' ]
);

=item %aaAbrev

Hash from one letter code for amino acids to the three
letter abbreviations. Includes ambiguous amino acids as well
as selenocysteine and pyrrolysine.

=cut

our %aaAbbrev = ( A => 'Ala',
                  B => 'Asx',
                  C => 'Cys',
                  D => 'Asp',
                  E => 'Glu',
                  F => 'Phe',
                  G => 'Gly',
                  H => 'His',
                  I => 'Ile',
                  J => 'Xle',
                  K => 'Lys',
                  L => 'Leu',
                  M => 'Met',
                  N => 'Asn',
                  O => 'Pyl',
                  P => 'Pro',
                  Q => 'Gln',
                  R => 'Arg',
                  S => 'Ser',
                  T => 'Thr',
                  U => 'Sec',
                  V => 'Val',
                  W => 'Trp',
                  X => 'Xaa',
                  Y => 'Tyr',
                  Z => 'Glx'
);

=item Basic Variables

Basic useful amino acid variables. A list of valid
characters for amino acids, a stricter list containing just
the 20 common ones and *, and another list containing the
ambiguous amino acids. Also associated precompiled
regular expressions.

=cut

our $aas     = '*ABCDEFGHIJKLMNOPQRSTUVWXYZ';
our $aaMatch = qr/[$aas]/i;
our $aaFail  = qr/[^$aas]/i;

our $strictAAs   = '*ACDEFGHIKLMNPQRSTVWXY';
our $strictMatch = qr/[$strictAAs]/i;
our $strictFail  = qr/[^$strictAAs]/i;

our $ambigs     = 'BJZ';
our $ambigMatch = qr/[$ambigs]/i;
our $ambigFail  = qr/[^$ambigs]/i;

1;

=back

=cut
