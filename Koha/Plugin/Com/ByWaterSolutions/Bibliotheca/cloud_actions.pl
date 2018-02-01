#!/usr/bin/perl

use Modern::Perl;

use C4::Context;
use lib C4::Context->config("pluginsdir");

use Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;

use CGI;

my $cgi = new CGI;
my $item_id = $cgi->param('item_id');
my $action  = $cgi->param('action');

my $_3m = Koha::Plugin::Com::ByWaterSolutions::Bibliotheca->new( { cgi => $cgi } );

if ( $action eq 'checkout' ) {
    $_3m->checkout($item_id);
} elsif ( $action eq 'checkin' ) {
    $_3m->checkin($item_id);
} elsif ( $action eq 'place_hold' ) {
    $_3m->place_hold($item_id);
} elsif ( $action eq 'cancel_hold' ) {
    $_3m->cancel_hold($item_id);
}

