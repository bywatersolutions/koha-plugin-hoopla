package Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Members;
use C4::Auth;
use Koha::DateUtils;
use Koha::Libraries;
use Koha::Patron::Categories;
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

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Bibliotheca eBook Plugin',
    author          => 'Nick Clemens',
    date_authored   => '2018-01-09',
    date_updated    => "1900-01-01",
    minimum_version => '16.06.00.018',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin utilises the Bibliotheca Cloud Library API',
};

our $uri_base = "https://partner.yourcloudlibrary.com";

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
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

## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    if ( $cgi->param('patron_info') || 1 ) {
        $self->patron_info();
    }
    else {
        $self->report_step2();
    }
}

## The existance of a 'tool' subroutine means the plugin is capable
## of running a tool. The difference between a tool and a report is
## primarily semantic, but in general any plugin that modifies the
## Koha database should be considered a tool
sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('submitted') ) {
        $self->tool_step1();
    }
    else {
        $self->tool_step2();
    }

}

## If your tool is complicated enough to needs it's own setting/configuration
## you will want to add a 'configure' method to your plugin like so.
## Here I am throwing all the logic into the 'configure' method, but it could
## be split up like the 'report' method is.
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            client_id     => $self->retrieve_data('client_id'),
            client_secret => $self->retrieve_data('client_secret'),
            library_id    => $self->retrieve_data('library_id'),
        );

        print $cgi->header();
        print $template->output();
    }
    else {
        $self->store_data(
            {
                client_id     => $cgi->param('client_id'),
                client_secret => $cgi->param('client_secret'),
                library_id    => $cgi->param('library_id'),
            }
        );
        $self->go_home();
    }
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('3mebooks');

    return C4::Context->dbh->do( "
        CREATE TABLE  $table (
            `borrowernumber` INT( 11 ) NOT NULL
        ) ENGINE = INNODB;
    " );
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('3mebooks');

    return C4::Context->dbh->do("DROP TABLE $table");
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub report_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 1, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");

    my $template = $self->get_template({ file => 'report-step1.tt' });
    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'GetPatronCirculation',patron_id=>$user});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    warn "$dt\n$auth\n$vers";
    my $response = $ua->get($uri_base.$uri_string, '3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers );
    $template->param( 'response' => $response->{_content} );


    print $cgi->header();
    print $template->output();
}

sub patron_info {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    warn "here at least";

    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 0, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");

    my $template = $self->get_template({ file => 'patron_info.tt' });
    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'GetPatronCirculation',patron_id=>$user});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    warn "$dt\n$auth\n$vers";
    my $response = $ua->get($uri_base.$uri_string, '3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers );
    $template->param( 'response' => $response->{_content}, 'bt_id'=>$user );


    print $cgi->header();
    print $template->output();
}

sub report_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $branch                = $cgi->param('branch');
    my $category_code         = $cgi->param('categorycode');
    my $borrower_municipality = $cgi->param('borrower_municipality');
    my $output                = $cgi->param('output');

    my $fromDay   = $cgi->param('fromDay');
    my $fromMonth = $cgi->param('fromMonth');
    my $fromYear  = $cgi->param('fromYear');

    my $toDay   = $cgi->param('toDay');
    my $toMonth = $cgi->param('toMonth');
    my $toYear  = $cgi->param('toYear');

    my ( $fromDate, $toDate );
    if ( $fromDay && $fromMonth && $fromYear && $toDay && $toMonth && $toYear )
    {
        $fromDate = "$fromYear-$fromMonth-$fromDay";
        $toDate   = "$toYear-$toMonth-$toDay";
    }

    my $query = "
        SELECT firstname, surname, address, city, zipcode, city, zipcode, dateexpiry FROM borrowers 
        WHERE branchcode LIKE '$branch'
        AND categorycode LIKE '$category_code'
    ";

    if ( $fromDate && $toDate ) {
        $query .= "
            AND DATE( dateexpiry ) >= DATE( '$fromDate' )
            AND DATE( dateexpiry ) <= DATE( '$toDate' )  
        ";
    }

    my $sth = $dbh->prepare($query);
    $sth->execute();

    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push( @results, $row );
    }

    my $filename;
    if ( $output eq "csv" ) {
        print $cgi->header( -attachment => 'borrowers.csv' );
        $filename = 'report-step2-csv.tt';
    }
    else {
        print $cgi->header();
        $filename = 'report-step2-html.tt';
    }

    my $template = $self->get_template({ file => $filename });

    $template->param(
        date_ran     => dt_from_string(),
        results_loop => \@results,
        branch       => GetBranchName($branch),
    );

    unless ( $category_code eq '%' ) {
        $template->param( category_code => $category_code );
    }

    print $template->output();
}

sub tool_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'tool-step1.tt' });

    print $cgi->header();
    print $template->output();
}

sub tool_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'tool-step2.tt' });

    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'GetMARC'});
    $uri_string .= "&offset=0&limit=20";
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    warn "$dt\n$auth\n$vers";
    my $response = $ua->get($uri_base.$uri_string, 'Date' => $dt ,'3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers );
    $template->param( 'response' => $response->{_content} );
    my $tmp = File::Temp->new();
    print $tmp $response->{_content};
    seek $tmp, 0, 0;
    $MARC::File::XML::_load_args{BinaryEncoding} = 'utf-8';
    my $marcFlavour = C4::Context->preference('marcflavour') || 'MARC21';
    my $recordformat= ($marcFlavour eq "MARC21"?"USMARC":uc($marcFlavour));
    $MARC::File::XML::_load_args{RecordFormat} = $recordformat;
    my $batch = MARC::Batch->new('XML',$tmp);
    $batch->warnings_off();
    $batch->strict_off();

    while ( my $marc = $batch->next ) {
        warn $marc->subfield(001,"a"), "\n";
        warn $marc->subfield(245,"a"), "\n";
    }

    print $cgi->header();
    print $template->output();
}

=head2 _get_request_ur

my ($error, $verb, $uri_string);

=head3 Creates the uri string for a given request.

Accepts parameters specifying desired action and returns uri and verb.

Cuurent actions are:
GetPatronCirculation
GetMARC

=cut

sub _get_request_uri {
    my ( $self, $params ) = @_;
    my $action = $params->{action};

    if ($action eq 'GetPatronCirculation') {
        my $patron_id = $params->{patron_id}; #FIXME shoudltake bnumber and allow config to set which is patronid
        return ("No patron",undef,undef) unless $patron_id;
        return (undef,"GET","/cirrus/library/".$self->retrieve_data('library_id')."/circulation/patron/".$patron_id);
    } elsif ($action eq 'GetMARC') {
        my $start_date = $params->{start_date} || $self->retrieve_data('last_marc_harvest');
        my $end_date = $params->{end_date} || "";
        my $uri_string = "/cirrus/library/".$self->retrieve_data('library_id')."/data/marc?startdate=$start_date";
        $uri_string .= "&enddate=".$end_date if $end_date;
        return (undef,'GET',$uri_string);
    }
}

=head2 _create_signature

=head3 Creates signature for requests.

Uses API to create a signature from the formatted date time, VERB, and API command path

=cut

sub _create_signature {
    my ( $self, $params ) = @_;
    my $Datetime = $params->{Datetime};
    my $verb = $params->{verb};
    my $URI_path = $params->{URI_path};
    my $query = $params->{query};
warn $Datetime."\n$verb\n".$URI_path;
    my $signature = hmac_sha256_base64($Datetime."\n$verb\n".$URI_path, $self->retrieve_data('client_secret'));

    return $signature;

}

=head2 _set_headers ( $verb )

=head3 Sets headers for user_agent and creates current signature

=cut

sub _get_headers {
    my $self = shift;
    my $verb = shift or croak "No verb";
    my $URI_path = shift or croak "No URI path";

    my $request_time = strftime "%a, %d %b %Y %H:%M:%S GMT", gmtime;
#    $request_time = "Tue, 09 Jan 2018 15:59:00 GMT";
    my $request_signature = $self->_create_signature({ Datetime => $request_time, verb => $verb, URI_path => $URI_path });
    while (length($request_signature) % 4) {
        $request_signature.= '=';
    }
    warn $request_signature;
    my $_3mcl_datetime = $request_time;
    my $_3mcl_Authorization = "3MCLAUTH ".$self->retrieve_data('client_id').":".$request_signature;
    my $_3mcl_APIVersion = "3.0";
    return ( $_3mcl_datetime,$_3mcl_Authorization,$_3mcl_APIVersion );

}

sub response_bad_request {
    my ($error) = @_;
    response({error => $error}, "400 $error");
}
sub response {
    my ($data, $status_line) = @_;
    $status_line ||= "200 OK";
#output_with_http_headers $cgi, undef, encode_json($data), 'json', $status_line;
    exit;
}



1;
