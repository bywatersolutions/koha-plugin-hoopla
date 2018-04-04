package Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Members;
use C4::Auth;
use C4::Biblio;
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
use XML::Simple;
use List::MoreUtils qw(uniq);

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Bibliotheca eBook Plugin',
    author          => 'Nick Clemens',
    date_authored   => '2018-01-09',
    date_updated    => "1900-01-01",
    minimum_version => '16.0600018',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin utilises the Bibliotheca Cloud Library API',
};

our $uri_base = "https://partner.yourcloudlibrary.com";

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

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            client_id       => $self->retrieve_data('client_id'),
            client_secret   => $self->retrieve_data('client_secret'),
            library_id      => $self->retrieve_data('library_id'),
            record_type     => $self->retrieve_data('record_type'),
        );

        print $cgi->header();
        print $template->output();
    }
    else {
        $self->store_data(
            {
                client_id       => $cgi->param('client_id'),
                client_secret   => $cgi->param('client_secret'),
                library_id      => $cgi->param('library_id'),
                record_type     => $cgi->param('record_type'),
            }
        );
        $self->go_home();
    }
}

sub install() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('records');
    my $table2 = $self->get_qualified_table_name('details');
    my $success = 0;

    $success = C4::Context->dbh->do( "
        CREATE TABLE IF NOT EXISTS $table (
            item_id VARCHAR( 32 ) NOT NULL,
            metadata longtext NOT NULL,
            biblionumber INT(10) NOT NULL
        ) ENGINE = InnoDB;
        ");
    return 0 unless $success;
    $success = C4::Context->dbh->do( "
        CREATE TABLE IF NOT EXISTS $table2 (
            item_id VARCHAR( 32 ) NOT NULL,
            title mediumtext,
            subtitle mediumtext,
            isbn mediumtext,
            author mediumtext,
            publisher mediumtext,
            publishdate text,
            publishyear smallint(6),
            format VARCHAR(16),
            language VARCHAR(16),
            rating VARCHAR(16),
            description mediumtext,
            size decimal(28,6),
            pages int(11),
            coverimage varchar(255)
        ) ENGINE = InnoDB;
      " );
      return $success;
}

sub uninstall() {
    my ( $self, $args ) = @_;

    my $table = $self->get_qualified_table_name('records');
    my $table2 = $self->get_qualified_table_name('details');

    return C4::Context->dbh->do("DROP TABLE $table");
}

sub browse_titles {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $table = $self->get_qualified_table_name('details');
    my $offset = $cgi->param('offset') || 0;
    my $limit = $cgi->param('limit') || 50;
    my $template = $self->get_template({ file => 'browse_titles.tt' });
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM $table LIMIT $limit OFFSET $offset;",{});
    $sth->execute();
    my $titles = $sth->fetchall_arrayref({});
    $template->param( titles => $titles );
    print $cgi->header();
    print $template->output();
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


    print $cgi->header();
    print $cgi->header('text/xml');
    print $response->{_content};
}

=head2 item_info

item_info();

=head3 Takes an array of item_ids and fetches and saves the item details

=cut

sub item_info {
    my ($self, $item_ids) = @_;
    my $cgi = $self->{'cgi'};
    my $item_detail_xml = $self->_get_item_details( $item_ids );
    if ( $item_detail_xml ) {
        print $cgi->header();
        print $cgi->header('text/xml');
        print $item_detail_xml;
    }
}


sub get_item_status {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my @item_ids = split(/,/, $cgi->param('item_ids'));
    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 0, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");
    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'GetItemStatus',patron_id=>$user,item_ids=>\@item_ids});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $response = $ua->get($uri_base.$uri_string, '3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers);
    print $cgi->header('text/xml');
    print $response->{_content};
}
sub get_isbn_status {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my @item_isbns = split(/,/, $cgi->param('item_ids'));
    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 0, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");
    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'GetIsbnSummary',patron_id=>$user,item_isbns=>\@item_isbns});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $response = $ua->get($uri_base.$uri_string, '3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers);
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
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'Checkin',patron_id=>$user,item_id=>$item_id});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $content = "<CheckinRequest><ItemId>$item_id</ItemId><PatronId>$user</PatronId></CheckinRequest>";
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
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'Checkout',patron_id=>$user,item_id=>$item_id});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $content = "<CheckoutRequest><ItemId>$item_id</ItemId><PatronId>$user</PatronId></CheckoutRequest>";
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
sub place_hold {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $item_id = $cgi->param('item_id');
    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 0, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");
    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'PlaceHold',patron_id=>$user,item_id=>$item_id});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $content = "<PlaceHoldRequest><ItemId>$item_id</ItemId><PatronId>$user</PatronId></PlaceHoldRequest>";
    my $response = $ua->put(
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
sub cancel_hold {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $item_id = $cgi->param('item_id');
    my ( $user, $cookie, $sessionID, $flags ) = checkauth( $cgi, 0, {}, 'opac' );
    $user && $sessionID or response_bad_request("User not logged in");
    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'CancelHold',patron_id=>$user,item_id=>$item_id});
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $content = "<CancelHoldRequest><ItemId>$item_id</ItemId><PatronId>$user</PatronId></CancelHoldRequest>";
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

sub fetch_records {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $start_date = $cgi->param('start_date');
    warn $start_date;
    my $limit = $cgi->param('limit');
    my $offset = $cgi->param('offset');
    $self->store_data({'last_marc_harvest' => output_pref({dt=>dt_from_string(),dateonly=>1,dateformat=>'sql'})});

    my $ua = LWP::UserAgent->new;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action => 'GetMARC', start_date=>$start_date});
    warn $uri_string;
    my $offset_string = "&offset=$offset&limit=$limit";
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string.$offset_string);
    my $response = $ua->get($uri_base.$uri_string.$offset_string, 'Date' => $dt ,'3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers );
    if ( $response->is_success && $response->{_content} ) {
        my $tmp = File::Temp->new();
        print $tmp $response->{_content};
        seek $tmp, 0, 0;
        $MARC::File::XML::_load_args{BinaryEncoding} = 'utf-8';
        my $marcFlavour = C4::Context->preference('marcflavour') || 'MARC21';
        my $recordformat= ($marcFlavour eq "MARC21"?"USMARC":uc($marcFlavour));
        $MARC::File::XML::_load_args{RecordFormat} = $recordformat;
        my $batch = MARC::Batch->new('XML',$tmp);
        close $tmp;
        $batch->warnings_off();
        $batch->strict_off();
        my @item_ids;
        while ( my $marc = $batch->next ) {
            push ( @item_ids, $self->_save_record( $marc ) );
        }
        print $cgi->header();
        my $items_processed = scalar uniq @item_ids;
        print "$items_processed";
    } else {
        print $cgi->header();
        print "No data in response";
    }
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


=head2 _save_record

_save_record(marc);

=head3 Takes a marcxml and saves the id and marcxml and fetches item data and saves it

=cut

sub _save_record {
    my ($self, $record) = @_;
    return unless $record;
    my $field_942 = MARC::Field->new( 942, '', '', 'c' => $self->retrieve_data("record_type") );
    $record->append_fields($field_942);
    my ($biblionumber,$biblioitemnumber) = AddBiblio($record,"");
    my $table = $self->get_qualified_table_name('records');
    my $item_id = $record->field('001')->as_string();
    return unless $item_id;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT biblionumber FROM $table WHERE item_id='$item_id';");
    $sth->execute();
    my $biblionumbers = $sth->fetchall_arrayref();
    foreach my $biblionumber (@$biblionumbers){
        DelBiblio(@$biblionumber[0]);
    }
    $sth = $dbh->prepare("DELETE FROM $table WHERE item_id=?");
    $sth->execute($item_id);
    my $saved_record = $dbh->do(
        qq{
            INSERT INTO $table ( item_id, metadata, biblionumber )
            VALUES ( ?, ?, ? );
        },
        {},
        $item_id,
        $record->as_xml_record('MARC21'),
        $biblionumber
    );
    return $item_id;
}

=head2 _get_item_details

_get_item_details(@item_ids);

=head3 Takes an array of iitem_ids and fetches the detail XML from the API

=cut

sub _get_item_details {
    my ($self, $item_ids) = @_;
    my ($error, $verb, $uri_string) = $self->_get_request_uri({action=>'GetItemData',item_ids=>$item_ids});
    my $ua = LWP::UserAgent->new;
    my($dt,$auth,$vers) = $self->_get_headers( $verb, $uri_string);
    my $response = $ua->get($uri_base.$uri_string, 'Date' => $dt ,'3mcl-Datetime' => $dt, '3mcl-Authorization' => $auth, '3mcl-APIVersion' => $vers );
    if ( $response->is_success ) {
        return( $response->{_content});
    }
}




=head2 _save_item_details

_save_item_details(@item_ids);

=head3 Takes an array of item_ids and fetches and saves the item details

=cut

sub _save_item_details {
    my ($self, $item_ids) = @_;
    my $item_detail_xml = $self->_get_item_details( $item_ids );
    if ( $item_detail_xml ) {
        my $item_details = XMLin( $item_detail_xml, ForceArray => 1 )->{DocumentData};
        my $table = $self->get_qualified_table_name('details');
        my $dbh = C4::Context->dbh;
        foreach my $item_detail ( @$item_details ) {
            $dbh->do("DELETE FROM $table WHERE item_id = '".$item_detail->{id}[0]."';");
            my $saved_details = $dbh->do(
                "
                    INSERT INTO $table ( item_id, title, subtitle, isbn, author, publisher,
                            publishdate, publishyear, format, language, rating, description )
                    VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? );
                ",
                {},
                $item_detail->{id}[0],
                $item_detail->{title}[0],
                $item_detail->{subtitle}[0],
                $item_detail->{isbn}[0],
                $item_detail->{author}[0],
                $item_detail->{publisher}[0],
                $item_detail->{publishdate}[0],
                $item_detail->{publishyear}[0],
                $item_detail->{format}[0],
                $item_detail->{language}[0],
                $item_detail->{rating}[0],
                $item_detail->{description}[0],
            );
        }
    }
}


=head2 _get_request_uri

my ($error, $verb, $uri_string) = _get_request_uri({ action => "ACTION"});

=head3 Creates the uri string for a given request.

Accepts parameters specifying desired action and returns uri and verb.

Current actions are:
GetPatronCirculation
GetMARC
GetItemData
Checkout


=cut

sub _get_request_uri {
    my ( $self, $params ) = @_;
    my $action = $params->{action};

    if ($action eq 'GetMARC') {
        my $start_date = $params->{start_date} || $self->retrieve_data('last_marc_harvest');
        my $end_date = $params->{end_date} || "";
        my $uri_string = "/cirrus/library/".$self->retrieve_data('library_id')."/data/marc?startdate=$start_date";
        $uri_string .= "&enddate=".$end_date if $end_date;
        return (undef,'GET',$uri_string);
    } elsif ( $action eq 'GetItemData') {
        my $item_ids = $params->{item_ids};
        return ("No item",undef,undef) unless $item_ids;
        return (undef,"GET","/cirrus/library/".$self->retrieve_data('library_id')."/item/data/".join(',',@$item_ids));
    } elsif ( $action eq 'GetItemStatus') {
        my $item_ids = $params->{item_ids};
        my $patron_id = $params->{patron_id}; #FIXME shoudltake bnumber and allow config to set which is patronid
        return ("No item",undef,undef) unless $item_ids;
        return (undef,"GET","/cirrus/library/".$self->retrieve_data('library_id')."/item/status/".$patron_id."/".join(',',@$item_ids));
    } elsif ( $action eq 'GetIsbnSummary') {
        my $item_isbns = $params->{item_isbns};
        return ("No item",undef,undef) unless $item_isbns;
        return (undef,"GET","/cirrus/library/".$self->retrieve_data('library_id')."/isbn/summary/".join(',',@$item_isbns));
    } elsif ( !$params->{patron_id} ){
        return ("No patron",undef,undef);
    } elsif ( $action eq 'Checkout') {
        my $patron_id = $params->{patron_id}; #FIXME shoudltake bnumber and allow config to set which is patronid
        return (undef,"POST","/cirrus/library/".$self->retrieve_data('library_id')."/checkout");
    } elsif ( $action eq 'Checkin') {
        my $patron_id = $params->{patron_id};
        return (undef,"POST","/cirrus/library/".$self->retrieve_data('library_id')."/checkin");
    } elsif ( $action eq 'PlaceHold') {
        my $patron_id = $params->{patron_id};
        return (undef,"PUT","/cirrus/library/".$self->retrieve_data('library_id')."/placehold");
    } elsif ( $action eq 'CancelHold') {
        my $patron_id = $params->{patron_id};
        return (undef,"POST","/cirrus/library/".$self->retrieve_data('library_id')."/cancelhold");
    } elsif ($action eq 'GetPatronCirculation') {
        my $patron_id = $params->{patron_id};
        return (undef,"GET","/cirrus/library/".$self->retrieve_data('library_id')."/circulation/patron/".$patron_id);
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
