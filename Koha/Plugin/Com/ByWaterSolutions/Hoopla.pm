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
    minimum_version => '22.0505000',
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
    my $auth_string = "Basic " . encode_base64($hoopla_user.":".$hoopla_pass,'');
    my $response = $ua->post($uri_base . "/api/v1/get-token",'Authorization' => $auth_string);
    warn Data::Dumper::Dumper( $response );
    my $content = decode_json( $response->{_content});

    my $token = $content->{access_token};
    $cache->set_in_cache('hoopla_api_token',$token,{ expiry => '3600'});
    return $token;
}

sub search {
    my $self = shift;
    my $query = shift;
    my $offset = shift;
    $offset //= 0;
    my $token = $self->get_token();
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($uri_base . "/api/v1/libraries/".$self->retrieve_data('default_library_id')."/search?q=".$query."&offset=".$offset,'Authorization' => "Bearer ".$token);
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
    return $content->{titles}[0] // "";
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
                padding-left: 1em;
            }
            .hoopla_result_bottom {
                border-bottom: 1px solid #000;
            }
            .hoopla_result_bottom td {
                padding-bottom: 10px;
            }
            #num_pagination {
                display: flex;
            }
            .hoopla_pagination .page-item {
                cursor: pointer;
            }
        </style>
        <div id="hoopla_modal" class="modal hide" tabindex="-1" role="dialog" aria-hidden="true">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header">
                        <h1 class="modal-title">Hoopla results</h1>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <div class="modal-body">
                        <ul class='hoopla_pagination pagination pagination-sm'>
                            <li class="page-item">
                                <a class="page-link hoopla_page" data-page="first" aria-label="Go to the first page"><i class="fa fa-fw fa-angle-double-left" aria-hidden="true"></i>  First</a>
                            </li>
                            <li class="page-item">
                                <a class="page-link hoopla_page" aria-label="Go to the previous page" data-page="previous"> <i class="fa fa-fw fa-angle-left" aria-hidden="true"></i>  Previous</a>
                            </li>
                            <li id="num_pagination" class="active">
                                <a class="page-link hoopla_current_page" data-page="1" aria-label="Go to page 1">1</a>
                            </li>
                            <li class="page-item">
                                <a class="page-link hoopla_page" aria-label="Go to the next page" data-page="next">Next <i class="fa fa-fw fa-angle-right" aria-hidden="true"></i></a>
                            </li>
                            <li class="page-item">
                                <a class="page-link hoopla_page" data-page="last" aria-label="Go to the last page">Last <i class="fa fa-fw fa-angle-double-right" aria-hidden="true"></i></a>
                            </li>
                        </ul>
                        <table id="hoopla_modal_results" class="table">
                        </table>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
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
