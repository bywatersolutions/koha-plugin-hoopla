package Koha::Plugin::Com::ByWaterSolutions::Hoopla;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth;
use Koha::Cache;

use LWP::UserAgent;
use Carp;
use POSIX;
use MIME::Base64;
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

#sub intranet_js {
#    my ( $self ) = @_;
#    return q|<script>var our_cloud_lib = "| . $self->retrieve_data('library_id') . q|";</script>
#             <script src="/api/v1/contrib/hoopla/static/js/hoopla.js"></script>
#    |;
#}

sub opac_js {
    my ( $self ) = @_;
    return q|<script>var our_cloud_lib = "| . $self->retrieve_data('library_id') . q|";</script>
             <script src="/api/v1/contrib/hoopla/static/js/hoopla.js"></script>
    |;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $libraries = Koha::Libraries->search();

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            default_library_id      => $self->retrieve_data('default_library_id'),
        );

        while( my $library = $libraries->next ){
            $template->param(
                $library->branchcode . "_library_id" => $self->retrieve_data($library->branchcode . "_library_id")
            );
        }

        print $cgi->header();
        print $template->output();
    }
    else {
        $self->store_data(
            {
                default_library_id      => $cgi->param('default_library_id'),
            }
        );
        while( my $library = $libraries->next ){
            $self->store_data({
                $library->branchcode . "_library_id" => $cgi->param($library->branchcode . "_library_id")
            });
        }
        $self->go_home();
    }
}

sub install() {
    my ( $self, $args ) = @_;
}

sub uninstall() {
    my ( $self, $args ) = @_;
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

    my $token = $content->{access_token};
    $cache->set_in_cache('hoopla_api_token',$token,{ expiry => '3600'});
    return $token;
}

sub search {
    my $self = shift;
    my $query = shift;
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($uri_base . "/api/v1/libraries/".$self->retrieve_data('default_library_id')."/search?q=".$query,'Authorization' => "Bearer ".$token);
    my $content = decode_json( $response->{_content});
    return $content;
}

sub details {
    my $self = shift;
    my $content_id = shift;
    $content_id -= 1; #This is the hack I figured to get specific item details, ask for 1 starting from the content before
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($uri_base . "/api/v1/libraries/".$self->retrieve_data('default_library_id')."/content?limit=1&startToken=".$content_id,'Authorization' => "Bearer ".$token);
    my $content = decode_json( $response->{_content});
    return $content->{titles}[0];
}

sub status {
    my ( $self, $patron ) = @_;
    my $library_id =  $self->retrieve_data($patron->branchcode . '_library_id') || $self->retrieve_data('default_library_id');
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($uri_base . "/api/v1/libraries/".$library_id."/patrons/".$patron->cardnumber."/status",'Authorization' => "Bearer ".$token);
    if( $response->{_rc} eq '400' ){
        my $content->{error} = 'Invalid card';
        return $content;
    }
    my $content = decode_json( $response->{_content});
    if ( defined $content->{currentlyBorrowed} && $content->{currentlyBorrowed} > 0 ){
        $response = $ua->get($uri_base . "/api/v1/libraries/".$library_id."/patrons/".$patron->cardnumber."/checkouts/current",'Authorization' => "Bearer ".$token);
        my $checkouts = decode_json( $response->{_content});
        $content->{checkouts} = $checkouts;
    }
    return $content;
}

sub checkout {
    my ( $self, $patron, $content_id ) = @_;
    my $library_id =  $self->retrieve_data($patron->branchcode . '_library_id') || $self->retrieve_data('default_library_id');
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->post($uri_base . "/api/v1/libraries/".$library_id."/patrons/".$patron->cardnumber."/".$content_id,'Authorization' => "Bearer ".$token);
    my $content = decode_json( $response->{_content});
#    my $content = { success => "fake checkout" }; # for debugging
    return $content;
}

sub checkin {
    my ( $self, $patron, $content_id ) = @_;
    my $library_id =  $self->retrieve_data($patron->branchcode . '_library_id') || $self->retrieve_data('default_library_id');
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->delete($uri_base . "/api/v1/libraries/".$library_id."/patrons/".$patron->cardnumber."/".$content_id,'Authorization' => "Bearer ".$token);
    if( $response->{_rc} eq '204' ){
        my $content->{success} = 'Item returned';
        return $content;
    } else {
        my $content->{error} = 'Not returned';
        return $content;
    }
}


sub opac_head {
    my ( $self ) = @_;

    return q|
        <style>
            #hoopla_modal_results {
                display: flex;
                flex-direction: column;
            }
            #hoopla_results {
                font-weight: 700;
            }
            .hoopla_result_bottom {
                border-bottom: 1px solid #000;
            }
            .hoopla_result_bottom td {
                padding-bottom: 10px;
            }
        </style>
        <div id="hoopla_modal" class="modal hide" tabindex="-1" role="dialog" aria-hidden="true">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <button type="button" class="closebtn" data-dismiss="modal" aria-label="Close">x</button>
                        <h3 class="modal-title">Hoopla results</h3>
                    </div>
                    <div class="modal-body">
                        <table id="hoopla_modal_results" class="table">
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
