package Koha::Plugin::Com::ByWaterSolutions::Hoopla;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Members;
use C4::Auth;
use C4::Biblio;
use C4::Output qw(&output_with_http_headers);
use Koha::DateUtils;
use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::Patron::Attribute::Types;
use Koha::Account;
use Koha::Account::Lines;
use MARC::Record;
use MARC::Batch;
use MARC::File::XML;
use File::Temp;
use Cwd qw(abs_path);
use URI::Escape qw(uri_unescape);
use LWP::UserAgent;
use Carp;
use POSIX;
use Digest::SHA qw(hmac_sha256_base64);
use MIME::Base64;
use XML::Simple;
use List::MoreUtils qw(uniq);
use HTML::Entities;
use Text::Unidecode;
use JSON;

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Hoopla Plugin',
    author          => 'Nick Clemens',
    date_authored   => '2020-04-16',
    date_updated    => "1900-01-01",
    minimum_version => '19.0500000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin utilises the Hoopla API',
};

our $uri_base = "https://hoopla-api.hoopladigital.com";

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub intranet_js {
    my ( $self ) = @_;
    return q|<script>var our_cloud_lib = "| . $self->retrieve_data('library_id') . q|";</script>
             <script src="/api/v1/contrib/hoopla/static/js/hoopla.js"></script>
    |;
}

sub opac_js {
    my ( $self ) = @_;
    return q|<script>var our_cloud_lib = "| . $self->retrieve_data('library_id') . q|";</script>
             <script src="/api/v1/contrib/hoopla/static/js/hoopla.js"></script>
    |;
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('delete') ) {
        $self->tool_step1();
    }
    else {
        $self->delete_records();
    }

}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });
        my $attributes = Koha::Patron::Attribute::Types->search({
            unique_id => 1,
        });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            library_id      => $self->retrieve_data('library_id'),
        );

        print $cgi->header();
        print $template->output();
    }
    else {
        $self->store_data(
            {
                library_id      => $cgi->param('library_id'),
            }
        );
        $self->go_home();
    }
}

sub install() {
    my ( $self, $args ) = @_;
}

sub uninstall() {
    my ( $self, $args ) = @_;
}

sub patron_info {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 0, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");

    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'GetPatronCirculation',patron_id=>$user});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $response = $ua->get($uri_base.$uri_string, '3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers );

    print $cgi->header('text/xml');
    print $response->{_content};
}


sub checkin {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $item_id = $cgi->param('item_id');
    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 0, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");
    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string,$cloud_id) = $self->_get_request_uri({action => 'Checkin',patron_id=>$user,item_id=>$item_id});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $content = "<CheckinRequest><ItemId>$item_id</ItemId><PatronId>$cloud_id</PatronId></CheckinRequest>";
    my $response = $ua->post(
        $uri_base.$uri_string,
        '3mcl-Datetime' => $dt,
        '3mcl-Authorization' => $auth,
        '3mcl-APIVersion' => $vers,
        'Content-type'=>'application/xml',
        'Content' => $content
    );
    print $cgi->header();
    print $response->{_content};
}

sub checkout {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $item_id = $cgi->param('item_id');
    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 0, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");
    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string,$cloud_id) = $self->_get_request_uri({action => 'Checkout',patron_id=>$user,item_id=>$item_id});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $content = "<CheckoutRequest><ItemId>$item_id</ItemId><PatronId>$cloud_id</PatronId></CheckoutRequest>";
    my $response = $ua->post(
        $uri_base.$uri_string,
        '3mcl-Datetime' => $dt,
        '3mcl-Authorization' => $auth,
        '3mcl-APIVersion' => $vers,
        'Content-type'=>'application/xml',
        'Content' => $content
    );
    print $cgi->header();
    print $response->{_content};
}


sub tool_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $last_harvest = $self->retrieve_data('last_marc_harvest') || '';

    my $template = $self->get_template({ file => 'tool-step1.tt' });
    $template->param( last_harvest => $last_harvest );

    print $cgi->header();
    print $template->output();
}


sub response_bad_request {
    my ($error) = @_;
    response({error => $error}, "400 $error");
}
sub response {
    my ($data, $status_line) = @_;
    $status_line ||= "200 OK";
#my $cgi = $self->{'cgi'};
#    output_with_http_headers $cgi, undef, encode_json($data), 'json', $status_line;
    exit;
}

sub get_token {
    my $self = shift;

    my $cache = Koha::Cache->new();
    my $token = $cache->get_from_cache('hoopla_api_token');
    if( !$token ){
        $token = $self->refresh_token($cache);
    }
    return $token unless !$token;
    warn "Error retrieving token";
    return;
}

sub refresh_token {
    my $self = shift;
    my $cache = shift;

    my $ua = LWP::UserAgent->new;
    my $hoopla_user = C4::Context->config('hoopla_api_username');
    my $hoopla_pass = C4::Context->config('hoopla_api_password');
    my $auth_string = "Basic " . encode_base64($hoopla_user.":".$hoopla_pass);
    my $response = $ua->post($uri_base . "/api/v1/get-token",'Authorization' => $auth_string);
    my $content = decode_json( $response->{_content});
    warn Data::Dumper::Dumper( $content );

    my $token = $content->{access_token};
    $cache->set_in_cache('hoopla_api_token',$token,{ expiry => '43000'});
    return $token;
}

sub search {
    my $self = shift;
    my $query = shift;
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($uri_base . "/api/v1/libraries/".$self->retrieve_data('library_id')."/search?q=".$query,'Authorization' => "Bearer ".$token);
    my $content = decode_json( $response->{_content});
    return $content;
}

sub details {
    my $self = shift;
    my $content_id = shift;
    $content_id -= 1; #This is the hack I figured to get specific itme details, ask for 1 starting from the content before
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($uri_base . "/api/v1/libraries/".$self->retrieve_data('library_id')."/content?limit=1&startToken=".$content_id,'Authorization' => "Bearer ".$token);
    my $content = decode_json( $response->{_content});
    return $content;
}

sub status {
    my ( $self, $cardnumber ) = @_;
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($uri_base . "/api/v1/libraries/".$self->retrieve_data('library_id')."/patrons/".$cardnumber."/status",'Authorization' => "Bearer ".$token);
    warn Data::Dumper::Dumper( $response );
    my $content = decode_json( $response->{_content});
    return $content;
}


sub opac_head {
    my ( $self ) = @_;

    return q|
        <style>
            #hoopla_results {
                font-weight: 700;
            }
        </style>
        <div id="hoopla_modal" class="modal hide" role="dialog">
            <div class="modal-dialog" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Hoopla results</h5>
                        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                            <span aria-hidden="true">&times;</span>
                        </button>
                    </div>
                    <div class="modal-body">
                        <table id="hoopla_modal_results">
                        </table>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                    </div>
                </div>
            </div>
        </div>
    |;
}


sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub static_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('staticapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return "hoopla";
}


1;
