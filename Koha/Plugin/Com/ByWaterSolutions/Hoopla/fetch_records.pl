#!/usr/bin/perl

use Modern::Perl;

use C4::Context;
use lib C4::Context->config("pluginsdir");

use Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;

use CGI;

my $cgi = new CGI;
my $action    = $cgi->param('action');
my $offset    = $cgi->param('offset') || 1;
my $start_date = $cgi->param('start_date');
my $limit     = $cgi->param('limit') || 50;
warn "offset $offset and start_date $start_date";
my $_3m = Koha::Plugin::Com::ByWaterSolutions::Bibliotheca->new( { cgi => $cgi } );
$_3m->fetch_records({ offset => $offset, start_date => $start_date, limit => $limit });
