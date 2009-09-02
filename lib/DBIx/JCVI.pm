# File: JCVI.pm
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
# DBIx::JCVI - open and cache a database connection

package DBIx::JCVI;

use strict;
use warnings;

use DBI;
use Params::Validate;
use Term::ReadKey;

=head1 NAME

DBIx::JCVI - open and cache a database connection

=head1 VERSION

Version 0.1.0

=cut

use version; our $VERSION = qv('0.1.0');

=head1 SYNOPSIS

    use DBIx::JCVI;

    # Database handle caching functions
    DBIx::JCVI->cache_dbh( $dbh );              # cache a new database handle
    my $dbh = DBIx::JCVI->get_cached_dbh();     # get the cached database handle

    # Export the cached database handle function
    use DBIx::JCVI ':dbh';                      # function name is dbh
    my $dbh = dbh();
    $dbh->prepare(...);
    dbh()->prepare(...);

    use DBIx::JCVI ( ':dbh' => 'cached_dbh' );  # method name is 'cached_dbh'
    use DBIx::JCVI qw( :dbh cached_dbh );       # same as above
    my $dbh = cached_dbh();

    # Credentials (username/password) functions
    my ( $username, $password ) = DBIx::JCVI->read_password_file( $filename );
    my ( $username, $password ) = DBIx::JCVI->read_sqshrc_credentials();
    my $password = DBIx::JCVI->prompt_password(); # Prompts user for password
    
    # Using them inline
    my $dbh = DBI->connect( $data_source, DBI::JCVI->read_password_file( $filename ) );
    my $dbh = DBI->connect( $data_source, DBIx::JCVI->read_sqshrc_credentials() );
    my $dbh = DBI->connect( $data_source, $username, DBIx::JCVI->prompt_password() );

=head1 DESCRIPTION

Automatically supply user/password and a bare connect string for DBI.

=cut

# Cached database handle
my $DBH;

sub import {
    my $class  = shift;
    my $caller = caller();    # Calling module

    for ( my $i = 0 ; $i < @_ ; $i++ ) {
        my $option = $_[$i];

        if ( $option eq ':dbh' ) {
            my $exported_dbh_method_name = 'dbh';

            # Check to see if an alternate function name was provided
            if ( ( $#_ > $i ) && ( $_[ $i + 1 ] !~ m/^:/ ) ) {
                $exported_dbh_method_name = $_[ ++$i ];

                # TODO validate passed function name
            }

            no strict 'refs';
            *{"${caller}::$exported_dbh_method_name"} =
              \&{"${class}::get_cached_dbh"};
        }
        else {
            die qq{Unrecognized option supplied to import: "$option"};
        }
    }
}

=head1 FUNCTIONS

=cut

=head2 cache_dbh

    DBIx::JCVI->cache_dbh( $dbh );

Cache the database handle for retrieval

=cut

sub cache_dbh {
    my $class = shift;
    my ($dbh) = validate_pos( @_, 1 );
    $DBH = $dbh;
}

=head2 get_cached_dbh

    my $dbh = DBIx::JCVI->get_cached_dbh();

Retrieve the cached database handle. This method is exported as 'dbh' if the
':dbh' tag is supplied on import, and it can also be exported with another name
of your choosing.

=cut

sub get_cached_dbh { return $DBH }

=head2 read_password_file

    my ( $username, $password ) = DBIx::JCVI->read_password_file( $password_file );

Read username from password file. A password file has the plaintext username on
the first line and the password on the second.

=cut

sub read_password_file {
    shift if ( $_[0] eq __PACKAGE__ );

    my ($pf) = validate_pos( @_, { type => Params::Validate::SCALAR } );

    open PF, $pf or die qq{Can't open password file "$pf"};

    # Read the first two lines
    my $username = <PF>;
    my $password = <PF>;
    chomp( $username, $password );

    close PF;

    die(qq{Unable to find username/password in password file $pf})
      unless ( $username && $password );

    return ( $username, $password );
}

=head2 read_sqshrc

    my $sqshrc_options = DBIx::JCVI->read_sqshrc();

Read all set option from the current user's sqshrc:

    \set username="foo"
    \set password="b@r"
    \set hostname="BAZ"
    \set database="qux"

=cut

sub read_sqshrc {
    open SQSHRC, "$ENV{HOME}/.sqshrc" or die "Can't open $ENV{USER}'s .sqshrc!";

    my %sqshrc;
    while (<SQSHRC>) {
        if (/\\set (\w+)="(.+)"/) {
            $sqshrc{$1} = $2;
        }
    }

    close SQSHRC;

    return \%sqshrc;
}

=head2 read_sqshrc_credentials

    my ( $username, $password ) = DBIx::JCVI->read_sqshrc_credentials();

Read the username and password from user's .sqshrc.

=cut

sub read_sqshrc_credentials {
    my $class = shift;

    my $sqshrc = $class->read_sqshrc(@_);

    die 'Unable to find username/password in .sqhrc'
      unless ( $sqshrc->{username} && $sqshrc->{password} );

    return @$sqshrc{qw( username password )};
}

=head2 prompt_password

    my $password = DBIx::JCVI->prompt_password();

Prompt for the user's password.

=cut

sub prompt_password {
    local $| = 1;

    print 'Password: ';

    ReadMode('noecho');
    my $password = ReadLine(0);
    chomp $password;
    ReadMode('restore');

    print "\n";
    return $password;
}

=head1 AUTHOR

"Kevin Galinsky", C<< <"kgalinsk at jcvi.org"> >>

=head1 BUGS

Please report any bugs or feature requests to C<< <"kgalinsk at jcvi.org"> >>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::SQSHRC

=head1 COPYRIGHT & LICENSE

Copyright 2009 J. Craig Venter Institute, all rights reserved.

=cut

1;    # End of DBIx::SQSHRC
