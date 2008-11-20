# DNATools
#
# $Author: kgalinsk $
# $Date: 2008-11-14 10:35:59 -0500 (Fri, 14 Nov 2008) $
# $Revision: 23931 $
# $HeadURL: http://isvn.tigr.org/ANNOTATION/DM_Scripts/lib/JCVI/DNATools.pm $

=head1 NAME

JCVI::DNATools - JCVI Basic DNA tools

=head1 SYNOPSES

 use JCVI::DNATools qw(:all);

 cleanDNA($seqRef);
 $seqRef = randomDNA(100);
 $revRef = reverseComplement($seqRef);

=head1 DESCRIPTION

Provides a set of functions and predefined variables which
are handy when working with DNA.

=head1 AUTHOR

Kevin Galinsky, <kgalinsk@jcvi.org>

=cut

package JCVI::DNATools;

use strict;
use warnings;

use Exporter 'import';

our %EXPORT_TAGS = (
    all => [
        qw(%degenerateMap

            $nucs
            $nucMatch
            $nucFail
            $degens
            $degenMatch
            $degenFail

            cleanDNA
            randomDNA
            reverseComplement)
    ],

    funcs => [
        qw(cleanDNA
            randomDNA
            reverseComplement)
    ]
);

our @EXPORT_OK = @{ $EXPORT_TAGS{all} };

=head1 VARIABLES

=over

=item %degenerateMap

Hash of degenerate nucleotides. Each entry contains a
reference to an array of nucleotides that each degenerate
nucleotide stands for.

=cut

our %degenerateMap = ( N => [ 'A', 'C', 'G', 'T' ],
                       V => [ 'A', 'C', 'G' ],
                       H => [ 'A', 'C', 'T' ],
                       D => [ 'A', 'G', 'T' ],
                       B => [ 'C', 'G', 'T' ],
                       M => [ 'A', 'C' ],
                       R => [ 'A', 'G' ],
                       W => [ 'A', 'T' ],
                       S => [ 'C', 'G' ],
                       Y => [ 'C', 'T' ],
                       K => [ 'G', 'T' ]
);

=item Basic Variables

Basic nucleotide variables that could be useful. $nucs is a
string containing all the nucleotides (including the
degenerate ones). $nucMatch and $nucFail are precompiled
regular expressions that can be used to match for/against
a nucleotide. $degen* is the same thing but with degenerates.

=cut

our $nucs     = 'ABCDGHKMNRSTUVWY';
our $nucMatch = qr/[$nucs]/i;
our $nucFail  = qr/[^$nucs]/i;

our $degens     = 'BDHKMNRSVWY';
our $degenMatch = qr/[$degens]/i;
our $degenFail  = qr/[^$degens]/i;

=back

=head1 FUNCTIONS

=over

=item cleanDNA()

=item $cleanRef = cleanDNA($seqRef);

Cleans the sequence for use. Strips out comments (lines
starting with '>') and whitespace, converts uracil to
thymine, and capitalizes all characters.

Examples:

 cleanDNA($seqRef);

 $seqRef = cleanDNA(\'actg');
 $seqRef = cleanDNA(\'act tag cta');
 $seqRef = cleanDNA(\'>some mRNA
                      acugauauagau
                      uauagacgaucc');

=cut

sub cleanDNA {
    my $seqRef = shift;

    $$seqRef = uc $$seqRef;
    $$seqRef =~ s/^>.*//m;
    $$seqRef =~ s/$nucFail+//g;
    $$seqRef =~ tr/U/T/;

    return $seqRef;
}

=item randomDNA()

=item $seqRef = randomDNA($length);

Generate random DNA for testing this module or your own
scripts. Default length is 100 nucleotides.

Example:

 $seqRef = randomDNA($length);

=cut

sub randomDNA {
    my $length = shift;
    $length = $length || 100;

    my $seq;
    $seq .= int rand 4 while ( $length-- > 0 );
    $seq =~ tr/0123/ACGT/;

    return \$seq;
}

=item reverseComplement()

=item $reverseRef = reverseComplement($seqRef);

Finds the reverse complement of the sequence and handles
degenerate nucleotides.

Example:

 $reverseRef = reverseComplement(\'act');

=cut

sub reverseComplement {
    my $seqRef = shift;

    my $reverse = reverse $$seqRef;
    $reverse =~ tr/acgtmrykvhdbnACGTMRYKVHDBN/tgcakyrmbdhvnTGCAKYRMBDHVN/;

    return \$reverse;
}

1;

=back

=cut
