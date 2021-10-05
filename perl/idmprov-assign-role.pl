#!/usr/bin/perl
# read values from CSV file and assign users to roles via SOAP
# (c) 2016 Norbert Klasen, norbert.klasen@microfocus.com

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Text::CSV_XS;
use SOAP::Lite;

sub assignUserToRole {
	my ( $client, $originator, $correlationID, $userDN, $roleDN,
		$effectiveDate, $expirationDate, $reason )
	  = @_;

	my $assignRequest = SOAP::Data->name(
		"assignRequest" => \SOAP::Data->value(
			SOAP::Data->name( "actionType"     => 'grant' ),
			SOAP::Data->name( "assignmentType" => 'USER_TO_ROLE' ),
			SOAP::Data->name( "correlationID"  => $correlationID ),

   #SOAP::Data->name( "effectiveDate"  => $effectiveDate ), #2016-03-04T10:53:17
			SOAP::Data->name( "expirationDate" => $expirationDate ),
			SOAP::Data->name( "identity"       => $userDN ),
			SOAP::Data->name( "originator"     => $originator ),
			SOAP::Data->name( "reason"         => $reason ),
			SOAP::Data->name(
				"roles" => \SOAP::Data->value(
					SOAP::Data->name(
						"dnstring" => \SOAP::Data->value(
							SOAP::Data->name( "dn" => $roleDN )
						)
					)
				)
			)
		)
	);

	my $som = $client->requestRolesAssignmentRequest($assignRequest);

	if ( $som->fault() ) {
		if (
			exists $som->fault()->{'detail'}->{'NrfServiceException'}
			->{'reason'} )
		{
			warn $som->fault()->{'detail'}->{'NrfServiceException'}->{'reason'};
		} else {
			warn Dumper( $som->fault() );
			exit 1;
		}

	} else {
		my $requestdn = $som->result()->{'dnstring'}->{'dn'};
		print
		  "submitted request to assign $userDN to role $roleDN: $requestdn\n";
	}
}

###
### main
###
sub main { }

# defaults
my $verbose        = 0;
my $help           = 0;
my $server         = 'localhost';
my $port           = 8180;
my $https          = 0;
my $binddn         = 'uaadmin';
my $password       = '';
my $input          = '';
my $encoding       = 'utf-8';
my $reason         = '';
my $originator     = $0;
my $correlationID  = time();
my $effectiveDate  = '';
my $expirationDate = '';

# parse command line options
Getopt::Long::Configure('bundling');
GetOptions(
	'v|verbose'         => \$verbose,
	'h|help'            => \$help,
	'H|server=s'        => \$server,
	'p|port=i'          => \$port,
	'e|tls'             => \$https,
	'D|binddn=s'        => \$binddn,
	'w|password=s'      => \$password,
	'i|input=s'         => \$input,
	'c|encoding=s'      => \$encoding,
	'r|reason=s'        => \$reason,
	'o|originator=s'    => \$originator,
	'l|correlationID=s' => \$correlationID,
	'effectiveDate=s'   => \$effectiveDate,
	'expirationDate=s'  => \$expirationDate,

) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(
	-message => "No input file specified.",
	-exitval => 1,
	-verbose => 0
) if $input eq "";

# configure TLS verification
# $ENV{HTTPS_CA_DIR} = '/etc/ssl/certs'
# $ENV{HTTPS_CA_FILE} = '/etc/ssl/certs/server-certificate.crt'
# $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0; # disable hostname verification
# $soap->ssl_opts( verify_hostname => 0 );

# set up SOAP connection
my $client =
  SOAP::Lite->new( proxy => "http"
	  . ( $https ? "s" : "" )
	  . "://$server:$port/IDMProv/role/service" );
$client->autotype(0);
$client->default_ns('http://www.novell.com/role/service');
$client->readable(1);

sub SOAP::Transport::HTTP::Client::get_basic_credentials {
	return $binddn => $password;
}

# open CSV file
my $input_csv = Text::CSV_XS->new(
	{
		sep_char         => ',',
		eol              => $/,
		binary           => 1,
		allow_whitespace => 1,
	}
);
open( my $input_fh, "<:encoding($encoding)", $input )
  or die "cannot open '$input': $!";

# read password if it was not set yet
if ( $password eq '' ) {
	print 'password: ';
	system( 'stty', '-echo' );
	chop( $password = <STDIN> );
	system( 'stty', 'echo' );
	print "\n";
}

# read first line as header names
$input_csv->column_names( $input_csv->getline($input_fh) );

# iterate over lines
while ( my $assignment = $input_csv->getline_hr($input_fh) ) {
	if (   !exists $assignment->{'user'}
		|| $assignment->{'user'} eq ""
		|| !exists $assignment->{'role'}
		|| $assignment->{'role'} eq "" )
	{
		print STDERR "mandatory 'user' or 'role' column value is missing\n",
		  Dumper($assignment);
		next;
	}
	assignUserToRole(
		$client,
		$originator,
		$assignment->{'correlationID'} ? $assignment->{'correlationID'}
		: $correlationID,
		$assignment->{'user'},
		$assignment->{'role'},
		$assignment->{'effectiveDate'} ? $assignment->{'effectiveDate'}
		: $effectiveDate,
		$assignment->{'expirationDate'} ? $assignment->{'expirationDate'}
		: $expirationDate,
		$assignment->{'reason'} ? $assignment->{'reason'} : $reason,
	);
}

close($input_fh);

__END__

=head1 NAME

idmprov-assign-role.pl - read values from CSV file and assign roles via SOAP

=head1 SYNOPSIS

idmprov-assign-role.pl [options]

 Options:
  -h|--help                  Help message
  -v|--verbose               Run in verbose mode (diagnostics to standard output)
  -H|--server HOSTNAME       Application server, defaults to localhost
  -p|--port PORT             Port on application server, defaults to 8180
  -e|--tls                   Use HTTPS
  -D|--binddn STRING         User name or LDAP DN
  -w|--password STRING       Password
  -i|--input FILENAME        Name of CSV file to read
  -c|--encoding CHARSET      Encoding used in the CSV file, defaults to utf-8
  -r|--reason STRING         Description of the request
  -o|--originator STRING     Originator of the request, defaults to name of this script
  -l|--correlationID STRING  CorrelationID of the request
  --effectiveDate ISO8601    Date role assignment becomes effective (server local time: yyyy-MM-dd'T'HH:mm:ss)
  --expirationDate ISO8601   Date role assignment expires (server local time: yyyy-MM-dd'T'HH:mm:ss)


=head1 OPTIONS

=over 8

=item B<-i|--input> FILENAME

Name of the CSV file to read role information from. First line must be the header.
Allowed column names are: 

  user (LDAP DN, mandatory)
 
  role (LDAP DN, mandatory)
 
  reason
 
  correlationID
 
  effectiveDate
 
  expirationDate
 
If a value is specified in the input, it takes precedence over values provided on the command line.
  
=item B<-h|--help>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file and assigns a role to a user for each line.

=head1 LICENSE

MIT

=cut
