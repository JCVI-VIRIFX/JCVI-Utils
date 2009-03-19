#!perl

use Test::More 'no_plan';

BEGIN {
    use_ok('JCVI::Translator');
}

my $seq = 'CTGATATCATGCATGCCATTCTCGACCGCTATGCGCCTCCTGTTCCTCGTGGGCCCAAAA';

my $translator = new JCVI::Translator();

ok(
    ${ $translator->translate( \$seq, { partial5 => 1 } ) } eq
      'LISCMPFSTAMRLLFLVGPK',
    'Translated properly'
);

ok( ${ $translator->translate( \$seq ) } eq 'MISCMPFSTAMRLLFLVGPK',
    'Translated frame 1' );

ok(
    ${ $translator->translate( \$seq, { lower => 1 } ) } eq
      '*YHACHSRPLCASCSSWAQ',
    'Translated frame 2'
);

ok(
    ${ $translator->translate( \$seq, { lower => 2 } ) } eq
      'DIMHAILDRYAPPVPRGPK',
    'Translated frame 3'
);

ok(
    ${ $translator->translate( \$seq, { strand => -1 } ) } eq
      'FWAHEEQEAHSGREWHA*YQ',
    'Translated frame -1'
);

ok(
    ${ $translator->translate( \$seq, { strand => -1, upper => 59 } ) } eq
      'FGPTRNRRRIAVENGMHDI',
    'Translated frame -2'
);

ok(
    ${ $translator->translate( \$seq, { strand => -1, upper => 58 } ) } eq
      'MGPRGTGGA*RSRMACMIS',
    'Translated frame -3'
);

ok(
    ${ $translator->translate( \$seq, { partial5 => 1 } ) } eq
      'LISCMPFSTAMRLLFLVGPK',
    q{Translated 5' partial frame 1}
);

ok(
    ${
        $translator->translate( \$seq,
            { strand => -1, upper => 58, partial5 => 1 } )
      } eq 'LGPRGTGGA*RSRMACMIS',
    q{Translated 5' partial frame -3}
);

