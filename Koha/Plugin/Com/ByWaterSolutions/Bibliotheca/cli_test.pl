use Koha::Plugins;
use Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;
use Modern::Perl;
use Getopt::Long;
use LWP::UserAgent;

my $message;
my @item_ids;
my $patron_id = "";
my $help;
my $verbose;

GetOptions(
    "m|message=s" => \$message,
    "i|item=s"    => \@item_ids,
    "p|patron=s"  => \$patron_id,
    "v|verbose+"   => \$verbose,
    "h|help|?"    => \$help
);

if ( 
    $help
    || !$message
    || !(@item_ids || $patron_id) ){
    say &help();
    exit();
}

my %actions = (
    "item_info"    => { action => "GetItemData", item_ids => \@item_ids },
    "item_summary" => { action => "GetItemSummary", item_ids => \@item_ids },
    "item_status"  => { action => "GetItemStatus", patron_id => $patron_id, item_ids => \@item_ids },
    "isbn_summary" => { action => "GetIsbnSummary", item_isbns => \@item_ids },
    "checkin"      => { action => "Checkin", content => "<CheckinRequest><ItemId>$item_ids[0]</ItemId><PatronId>$patron_id</PatronId></CheckinRequest>" },
    "checkout"     => { action => "Checkout", content => "<CheckoutRequest><ItemId>$item_ids[0]</ItemId><PatronId>$patron_id</PatronId></CheckoutRequest>" },
    "place_hold"   => { action => "PlaceHold", content => "<PlaceHoldRequest><ItemId>$item_ids[0]</ItemId><PatronId>$patron_id</PatronId></PlaceHoldRequest>" },
    "cancel_hold"  => { action => "CancelHold", content => "<CancelHoldRequest><ItemId>$item_ids[0]</ItemId><PatronId>$patron_id</PatronId></CancelHoldRequest>" },
    "patron_acct"  => { action => "GetPatronCirculation", patron_id => $patron_id }
);

my $uri_base = "https://partner.yourcloudlibrary.com";
my $plugin = Koha::Plugin::Com::ByWaterSolutions::Bibliotheca->new();
my $ua     = LWP::UserAgent->new;

my $params;
#$params->{patron_id} = $patron_id // undef;
#$params->{item_id} = scalar @item_ids == 1 ? $item_id[0] // undef;
#$params->{action}  = $actions{$message};
$params = $actions{$message};
my ($error, $verb, $uri_string) = $plugin->_get_request_uri($params);
print "Verb: $verb | URI:$uri_string\n" if $verbose;
my($dt,$auth,$vers) = $plugin->_get_headers( $verb, $uri_string);
print "3mcl-Datetime: $dt | 3mcl-Authorization: $auth | 3mclAPIVersion: $vers\n" if $verbose;
my $response;
if ( $verb eq "GET" ){
    $response = $ua->get($uri_base.$uri_string, '3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth,'3mcl-APIVersion' => $vers );
} else {
    $response = $ua->post($uri_base.$uri_string, '3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth,'3mcl-APIVersion' => $vers, 'Content-type' => 'application/xml', Content => $actions{$message}->{content} );
}
if ( $verbose < 2 ){
    print Data::Dumper::Dumper( $response->{_content} );
} else {
    print Data::Dumper::Dumper( $response );
}

sub help {
    say q/cli_test.pl - command line tester for Bibliotheca plugin

Test messages and responses for CloudLibrary Integration.

Usage:
    cli_test.pl [OPTIONS]

Options:
    --help         display this message
    -i --item      Identifier for an item - either cloudID or ISBN depending on message
    -p --patron    Identifier used to log patron in to CloudLibrary
    -m --message   Which message to test


Messages:
    item_info: Gets detailed display info, requires item cloudID
    item_summary: Gets brief info, requires item cloudID
    item_status:  Gets status of item, requires patron and cloudID
    isbn_summary: Gets summart by ISBN, requires patron and ISBN
    checkin:      Return an item, requires patron and cloudID
    checkin:      Borrow an item, requires patron and cloudID
    place_hold:   Place holds, requires patron and cloudID
    cancel_hold:  Cancel hold, requires patron adn cloudID
    patron_acct:  Get patron account info
/
}
