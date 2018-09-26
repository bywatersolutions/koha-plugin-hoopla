#!/usr/bin/perl

#Included for command line testing of the cloud API
#For debug purposes only

use Modern::Perl;

use Config;
use Switch;
use C4::Context;
my $pluginsdir = C4::Context->config("pluginsdir");
my @pluginsdir = ref($pluginsdir) eq 'ARRAY' ? @$pluginsdir : $pluginsdir;
my $plugin_libs = '/Koha/Plugin/Com/ByWaterSolutions/';
foreach my $plugin_dir (@pluginsdir){
    my $local_libs = "$plugin_dir/$plugin_libs";
    unshift( @INC, $local_libs );
    unshift( @INC, "$local_libs/$Config{archname}" );
}

use Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;

use Getopt::Long;
my $action;
my $data;

GetOptions(
    'action=s' => \$action,
    'data=s'   => \$data,
);

warn "Action is $action";
warn "Data is $data";

my $params;
switch ($action) {
    case 'GetPatronCirculation' { $params = { action => $action, patron_id => $data }; }
    case 'GetItemStatus'        { $params = { action => $action, item_ids => $data }; }
    case 'GetItemSummary'       { $params = { action => $action, item_ids => [$data] }; }
}

use CGI;

our $uri_base = "https://partner.yourcloudlibrary.com";

my $cgi = new CGI;
my $_3m = Koha::Plugin::Com::ByWaterSolutions::Bibliotheca->new({ cgi => $cgi });

my $ua = LWP::UserAgent->new;
my ($error, $verb, $uri_string) = $_3m->_get_request_uri($params);
my($dt,$auth,$vers) = $_3m->_get_headers( $verb, $uri_string);
my $response = $ua->get($uri_base.$uri_string, '3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers );
warn Data::Dumper::Dumper( $response );
