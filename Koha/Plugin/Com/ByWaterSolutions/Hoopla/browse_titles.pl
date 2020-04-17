#!/usr/bin/perl

use Modern::Perl;

use C4::Context;
use lib C4::Context->config("pluginsdir");

use Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;

use CGI;

my $cgi = new CGI;

my $_3m =  Koha::Plugin::Com::ByWaterSolutions::Bibliotheca->new( { cgi => $cgi } );
  $_3m->browse_titles();

