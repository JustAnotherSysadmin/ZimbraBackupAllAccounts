#!/usr/bin/perl
##!/usr/bin/perl -w

###############################################################################
# Purpose:  Backup a complete Zimbra-based account as a tgz file.
#
# Method:  run this script by passing the email address to backup.
#   ie: ./backup.pl  john@example.com
#
# Author: Mike Cathey and modifications by John Lucas
#
#############
# Debian install dependancies:
#   apt install libssl-dev
# next run "cpan", then "install CPAN", then "reload cpan", then 
# install HTTP::Request::Common HTTP::Cookies Data::Dumper XML::Simple LWP::UserAgent Crypt::SSLeay IO::Socket::SSL File::Path

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use Data::Dumper;
use XML::Simple;
use File::Path qw(make_path);
# use LWP::Debug qw(+);
use POSIX qw/strftime/;
my $myDate = strftime('%Y-%m-%d',localtime);

my $zimbraURL = "https://mail.example.com:7071/service/admin/soap";
my $zimbraAdmin = "john\@example.com";
my $zimbraAdminPassword = "TheSecurePassword";
my $domain = "example.com"; ## added by JL as "$domain" is used below
my $zimbraAuthToken = "";
my $userZimbraAuthToken = "";
my $soap = "";
my $email = "";
# 1MB
#my $chunkSize = "1048576";
# 16MB
my $chunkSize = "16777216";


## test to see if the command line argument seems to be an email
if ( $ARGV[0] !~ /^[a-z0-9_.\-]+\@[a-z0-9.\-]+\.[a-z0-9]{1,4}$/i )  
{
	die("Invalid email address! $ARGV[0]\n");
} else {
	$email = $ARGV[0];
}

## This is the URL used to obtain the actual tgz:
# my $zimbraPublicURL = "https://mail-2.01.com/home/" . $email . "/?fmt=tgz";
my $zimbraPublicURL = "/home/" . $email . "/?fmt=tgz";

my $ua = new LWP::UserAgent;


## Administrative authenticataion soap string

# check zimbra (soap)
$soapAuthRequest = "<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\">
  <soap:Header>
    <context xmlns=\"urn:zimbra\" />
  </soap:Header>
  <soap:Body>
    <AuthRequest xmlns=\"urn:zimbraAdmin\">
      <name>$zimbraAdmin</name>
      <password>$zimbraAdminPassword</password>
    </AuthRequest>
  </soap:Body>
</soap:Envelope>";


# $soapRequest = "<GetDomainRequest attrs="{req-attrs}"]>
#$soapGetDomainRequest = "<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\">
#<soap:Header>
#    <context xmlns=\"urn:zimbra\">
#      <authToken>AUTH_TOKEN</authToken>
#    </context>
#  </soap:Header>
#  <soap:Body>
#    <GetDomainInfoRequest>
#        <domain by=\"name\">$domain</domain>
#    </GetDomainInfoRequest>
#  </soap:Body>
#</soap:Envelope>";

$soapGetDomainRequest = "<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\">
  <soap:Header>
    <context xmlns=\"urn:zimbra\">
      <authToken>AUTH_TOKEN</authToken>
    </context>
  </soap:Header>
  <soap:Body>
    <GetDomainRequest applyConfig=\"1\" xmlns=\"urn:zimbraAdmin\">
      <domain by=\"name\">DOMAIN</domain>
    </GetDomainRequest>
  </soap:Body>
</soap:Envelope>";

$soapGetAccountInfoRequest = "<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\">
<soap:Header>
  <context xmlns=\"urn:zimbra\">
    <authToken xmlns=\"\">AUTH_TOKEN</authToken>
  </context>
</soap:Header>
<soap:Body>
  <GetAccountInfoRequest xmlns=\"urn:zimbraAdmin\">
    <account by=\"name\">EMAIL_ADDRESS</account>
  </GetAccountInfoRequest>
</soap:Body>
</soap:Envelope>";

# <GetAccountRequest  [attrs="{req-attrs}"]>

$soapGetAllServersRequest = "<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\">
<soap:Header>
  <context xmlns=\"urn:zimbra\">
    <authToken xmlns=\"\">AUTH_TOKEN</authToken>
  </context>
</soap:Header>
<soap:Body>
  <GetAllServersRequest xmlns=\"urn:zimbraAdmin\" service=\"mailbox\"/>
</soap:Body>
</soap:Envelope>";

$soapDelegateAuthRequest = "<soap:Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\">
<soap:Header>
  <context xmlns=\"urn:zimbra\">
    <authToken xmlns=\"\">AUTH_TOKEN</authToken>
  </context>
</soap:Header>
<soap:Body>
 <DelegateAuthRequest xmlns=\"urn:zimbraAdmin\">
   <account by=\"name\">EMAIL_ADDRESS</account>
 </DelegateAuthRequest>
</soap:Body>
</soap:Envelope>";

$response = "";
$response = $ua->request(POST $zimbraURL,
Content_Type => 'text/xml',
Content => $soapAuthRequest);

if ($response->is_success)
{
        $soap = $response->decoded_content;
        # FIXME auth failure?
        $zimbraAuthToken = $soap;
        $zimbraAuthToken =~ s/^.*authToken>(.*)<\/authToken.*$/$1/s;
        # print "zimbraAuthToken = $zimbraAuthToken\n";
        # if we end up with what looks like a valid auth token, continue
        if ( $zimbraAuthToken =~ m/^[a-z0-9_]+$/i )
        {
                $soapDelegateAuthRequest =~ s/AUTH_TOKEN/$zimbraAuthToken/gs;
                $soapDelegateAuthRequest =~ s/EMAIL_ADDRESS/$email/gs;
                # print $soapDelegateAuthRequest;
                $response = "";
                $response = $ua->request(POST $zimbraURL,
                Content_Type => 'text/xml',
                Content => $soapDelegateAuthRequest);
                if ($response->is_success)
                {
			$soap = "";
                        $soap = $response->decoded_content;
                        # print $soap;
			my $xml = new XML::Simple;
			my $data = $xml->XMLin($soap,KeyAttr => 'authToken');;
                        # print Dumper($data);
			$userZimbraAuthToken = $data->{'soap:Body'}->{'DelegateAuthResponse'}->{'authToken'};

			# check to see if we have a valid auth token
		        if ( $userZimbraAuthToken =~ m/^[a-z0-9_]+$/i )
		        {
 
		                $soapGetAccountInfoRequest =~ s/AUTH_TOKEN/$zimbraAuthToken/gs;
		                $soapGetAccountInfoRequest =~ s/EMAIL_ADDRESS/$email/gs;
		                # print $soapGetAccountInfoRequest . "\n";
		                $response = "";
		                $response = $ua->request(POST $zimbraURL,
		                Content_Type => 'text/xml',
		                Content => $soapGetAccountInfoRequest);
		                if ($response->is_success)
		                {
					my $soap = $response->decoded_content;
					my $xml = new XML::Simple;
					my $data = $xml->XMLin($soap);
					#  => 'https://mail-2.01.com:443',
				        $zimbraPublicURL = $data->{'soap:Body'}->{'GetAccountInfoResponse'}->{'publicMailURL'} . $zimbraPublicURL;

			                $response = "";
					$ua->default_header('Cookie' => "ZM_AUTH_TOKEN=$userZimbraAuthToken");
					sub callback {
						my ($data, $response, $protocol) = @_;
						# $final_data .= $data;
						open(BACKUP, ">>$myDate/$myDate-$email-ZimbraAllFolders.tgz") or die("Can't write to $email.tgz: $!\n");
			                        print BACKUP $data;
						close BACKUP;
					}

					# $ua->max_size( $chunkSize )  # chunk size
			                $response = $ua->get( $zimbraPublicURL, ':content_cb' => \&callback, ':read_size_hint' => $chunkSize);
	
			                if ($response->is_success)
			                {
						# uses: File::Path and can create paths like "mkdir -p "
						make_path($myDate, { verbose => 0, mode => 0700 });
						sleep 5;
						# $ua->max_size( $bytes )  # chunk size
						
					} else {
			                        print $response->error_as_HTML;
						die("Error: Unable to fetch user tgz $email\n");
					}
				} else {
		                        print $response->error_as_HTML;
					die("GetAccountRequest Failed for $email");
				}


			} else {
				# we didn't get what we think is a valid auth token
	                        print $response->error_as_HTML;
				die("Error: DelegateAuthRequest unable to extract user auth token for $email\n");
			}

                }
                else
                {
                        print $response->error_as_HTML;
			die("Error: DelegateAuthRequest failed for $email\n");
                }



        }
        else
        {
                print "Error:  Unable to extract Zimbra auth token for $email\n";
		die("Error: DelegateAuthRequest failed for $email\n");
        }
}
else
{
	print $response->error_as_HTML;
	die("Error: Auth failed for $zimbraAdmin\n");
}
