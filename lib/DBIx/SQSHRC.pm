# File: SQSHRC.pm
# Author: kgalinsk
# Created: Jun 24, 2009
#
# $Author$
# $Date$
# $Revision$
# $HeadURL$
#
# Copyright 2009, J. Craig Venter Institute
#
# DBIx::SQSHRC - connect to sybase database given the user's sqshrc

package DBIx::SQSHRC;

use warnings;
use strict;

use Params::Validate;
use DBI;

=head1 NAME

DBIx::SQSHRC - connect to sybase database given the user's sqshrc

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use DBIx::SQSHRC;

    my $dbh = DBIx::SQSHRC->connect();
    my $dbh = DBIx::SQSHRC->connect( $data_source );
    my $dbh = DBIx::SQSHRC->connect( $data_source, \%attr );

    my ($username, $password) = DBIx::SQSHRC->read();

=head1 DESCRIPTION

Automatically supply user/password and a bare connect string for DBI.

=head1 FUNCTIONS

=head2 connect

    my $dbh = DBIx::SQSHRC->connect();
    my $dbh = DBIx::SQSHRC->connect( $data_source );
    my $dbh = DBIx::SQSHRC->connect( $data_source, \%attr );

Connect to the database using DBI. Returns a database handle. See DBI for more
info. Both parameters are optional; "dbi:Sybase:" is prepended/supplied for
$data_source strings automatically. 

=cut

sub connect {
    my $class = shift;

    my ( $data_source, $attr ) = validate_pos(
        @_,
        { default => '', type => Params::Validate::SCALAR },
        { default => {}, type => Params::Validate::HASHREF }
    );

    # Prepend dbi:Sybase: if it isn't already there
    $data_source =~ s/^(?:dbi:Sybase:)*/dbi:Sybase:/;
    
    DBI->connect($data_source, $class->read(), $attr);
}

=head2 read

    my ( $username, $password ) = DBIx::SQSHRC->read();

Read the username and password from .sqshrc

=cut

sub read {
    open SQSHRC, "$ENV{HOME}/.sqshrc" or die "Can't open $ENV{USER}'s .sqshrc!";

    my ( $username, $password );
    while (<SQSHRC>) {
        $username = $1 if (/\\set username="([^"]+)"/);
        $password = $1 if (/\\set password="([^"]+)"/);
    }

    close SQSHRC;

    die 'Unable to find username/password in .sqhrc'
      unless ( $username && $password );

    return ( $username, $password );
}

=head1 AUTHOR

"Kevin Galinsky", C<< <"kgalinsk at jcvi.org"> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbix-sqshrc at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-SQSHRC>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::SQSHRC

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-SQSHRC>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-SQSHRC>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-SQSHRC>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-SQSHRC/>

=back

=head1 ACKNOWLEDGEMENTS

DBI.

=head1 COPYRIGHT & LICENSE

Copyright 2009 "Kevin Galinsky", all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;    # End of DBIx::SQSHRC
