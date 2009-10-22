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

Version 0.1.1

=cut

use version; our $VERSION = qv('0.1.1');

=head1 SYNOPSIS

    use DBIx::JCVI;

    # Database handle caching functions
    DBIx::JCVI->cache_dbh( $dbh );                  # cache a new database handle
    my $dbh = DBIx::JCVI->get_cached_dbh();         # get the cached database handle

    # Export the cached database handle function
    use DBIx::JCVI ':export';                       # function name is dbh
    my $dbh = dbh();
    $dbh->prepare(...);
    dbh()->prepare(...);

    use DBIx::JCVI ( ':export' => 'cached_dbh' );   # method name is 'cached_dbh'
    use DBIx::JCVI qw( :export cached_dbh );        # same as above
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

        if ( $option eq ':export' ) {
            my $exported_method_name = 'dbh';

            # Check to see if an alternate function name was provided
            if ( ( $#_ > $i ) && ( $_[ $i + 1 ] !~ m/^:/ ) ) {
                $exported_method_name = $_[ ++$i ];

                die 'A reference was passed for the function name'
                  if ( ref($exported_method_name) );
                die 'An empty function name was passed'
                  unless ($exported_method_name);
            }

            no strict 'refs';
            *{"${caller}::$exported_method_name"} =
              \&{"${class}::get_cached_dbh"};

            next;
        }

        die qq{Unrecognized option supplied to import: "$option"};
    }
}

=head1 FUNCTIONS

=cut

=head2 connect

    my $dbh = DBIx::JCVI->connect( $database,
        {
            driver     => $driver,      # default is 'Sybase'
            username   => $username,    # default is $ENV{USER}
            password   => $password,
            method     => $method,      # method for selecting credentials
            arguments  => $arguments,   # arguments to pass to the method
            dsn        => $dsn,         # miscellaneous stuff to put in the DSN
            attributes => \%attributes, # attributes to pass to connect
            cache      => $bool,        # cache the handle? default is false
        }
    );

The username/password supercede the credentials returned from the method. The
arguments are optional and are passed to the method. This takes the input and
then connects to the database.

=cut

my %METHODS = (
    sqshrc        => 'read_sqshrc_credentials',
    prompt        => undef,
    password_file => 'read_password_file'
);

sub connect {
    my $class = shift;

    # Get arguments
    my ( $database, @p ) = validate_pos(
        @_,
        { type     => Params::Validate::SCALAR },
        { optional => 1, type => Params::Validate::HASHREF }
    );
    my %p = validate(
        @p,
        {
            driver => {
                default => 'Sybase',
                type    => Params::Validate::SCALAR,
                regex   => qr/^(?:Sybase:SQLite)$/
            },
            username => { optional => 1, type => Params::Validate::SCALAR },
            password => { optional => 1, type => Params::Validate::SCALAR },
            method   => {
                default   => 'sqshrc',
                type      => Params::Validate::SCALAR,
                callbacks => {
                    'valid method' => sub { exists $METHODS{ $_[0] } }
                }
            },
            arguments => { optional => 1 },
            dsn       => {
                optional => 1,
                type     => Params::Validate::SCALAR | Params::Validate::HASHREF
            },
            attributes => { default  => {}, type => Params::Validate::HASHREF },
            cache      => { optional => 1 }
        }
    );

    my $dbh;
    if ( $p{driver} eq 'SQLite' ) {
        $dbh = DBI->connect( "dbi:SQLite:dbname=$database", '', '' );
    }
    else {

        # Figure out credentials
        my ( $username, $password ) = @p{qw( username password )};

        # If password was supplied but not username, assume current user
        if ( $password && ( !$username ) ) { $username = $ENV{USER} }
        elsif ( !( $username && $password ) ) {

            # Only prompt for data that wasn't supplied
            if ( $p{method} eq 'prompt' ) {
                if ($username) { $password = $class->prompt_password() }
                else {
                    ( $username, $password ) =
                      $class->prompt_username_password( @{ $p{arguments} } );
                }
            }

            # Rest of methods are more straightforward
            else {
                my $method      = $METHODS{ $p{method} };
                my @credentials = $class->$method( @{ $p{arguments} } );

                $username ||= $credentials[0];
                $password ||= $credentials[1];
            }

            if ( !( $username && $password ) ) {
                die 'Incomplete credentials';
            }
        }

        # Build the data source string
        my $data_source = "dbi:$p{driver}:database=$database";
        if ( $p{dsn} ) {
            unless ( ref $p{dsn} ) {
                $data_source .= ";$p{dsn}";
            }
            else {
                my @dsn = map { "$_=$p{dsn}{$_}" } keys %{ $p{dsn} };
                $data_source = join( ';', $data_source, @dsn );
            }
        }

        $dbh =
          DBI->connect( $data_source, $username, $password, $p{attributes} )
          or die "Unable to connect to the database: $DBI::errstr";
    }

    if ( $p{cache} ) {
        $class->cache_dbh($dbh);
    }

    return $dbh;
}

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
':export' tag is supplied on import, and it can also be exported with another
name of your choosing.

=cut

sub get_cached_dbh { return $DBH }

=head2 read_password_file

    my ( $username, $password ) = DBIx::JCVI->read_password_file( $password_file );

Read username from password file. A password file has the plaintext username on
the first line and the password on the second.

=cut

sub read_password_file {
    my $class = shift;

    my ($pf) = validate_pos( @_, { type => Params::Validate::SCALAR } );

    open PF, $pf or die qq{Can't open password file "$pf": $!};

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
    open SQSHRC, "$ENV{HOME}/.sqshrc"
      or die "Can't open $ENV{USER}'s .sqshrc!";

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

=head2 prompt_username

    my $username = DBIx::JCVI->prompt_username();
    my $username = DBIx::JCVI->prompt_username( $default_username );

Prompt for the user's password.

=cut

sub prompt_username {
    my $class = shift;
    my $default = $_[0] || $ENV{USER};

    local $| = 1;

    print "Username [$default]: ";
    my $username = <STDIN>;
    chomp $username;
    $username ||= $default;
}

=head2 prompt_username_password

    my ( $username, $password ) = DBIx::JCVI->prompt_username_password();
    my ( $username, $password ) = DBIx::JCVI->prompt_username_password( $default_username );

Prompt for username and password.

=cut

sub prompt_username_password {
    my $class = shift;

    my $username = $class->prompt_username(@_);
    my $password = $class->prompt_password();

    return ( $username, $password );
}

=head1 AUTHOR

"Kevin Galinsky", C<< <"kgalinsk at jcvi.org"> >>

=head1 BUGS

Please report any bugs or feature requests to C<< <"kgalinsk at jcvi.org"> >>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::JCVI

=head1 COPYRIGHT & LICENSE

Copyright 2009 J. Craig Venter Institute, all rights reserved.

=cut

1;
