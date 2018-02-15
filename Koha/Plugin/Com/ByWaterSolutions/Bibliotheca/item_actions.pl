#!/usr/bin/perl

use Modern::Perl;

use C4::Context;
use lib C4::Context->config("pluginsdir");

use Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;

use CGI;

my $cgi = new CGI;
my $action   = $cgi->param('action');
my $item_ids = $cgi->param('item_ids');
my @item_ids = split(/,/,$item_ids);
$item_ids = \@item_ids;

my $_3m = Koha::Plugin::Com::ByWaterSolutions::Bibliotheca->new( { cgi => $cgi } );
if ( $action eq 'status' ) {
    $_3m->get_item_status($item_ids);
} elsif ( $action eq 'info' ) {
    $_3m->item_info($item_ids);
}

