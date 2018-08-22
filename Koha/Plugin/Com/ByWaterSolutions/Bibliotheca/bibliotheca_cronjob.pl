#!/usr/bin/perl

use Modern::Perl;

use Koha::Plugins;
use Koha::Plugin::Com::ByWaterSolutions::Bibliotheca;
use Getopt::Long;

=head1 NAME

bibliotheca_cronjob.pl - As part of the Bibliotheca plugin this cronjob will automate fetching new records
from the 3m account setup in the plugin. It will fetch records since the last run date unless a start date is provided.
Each run will store the current date as the last run

=head1 SYNOPSIS

bibliotheca_cronjob.pl [--start=1999-01-01]

bibliotheca_cronjob.pl --help | --man

Options:
  --help       prints this info
  --man        prints the same
  --start=date fetch records added since given date

=head1 OPTIONS

=over 8

=item B<--help>

Prints help and exits

=item B<--man>

Prints help and exits

=item B<--start>

Fetch records from given date. If not provided it will use the last run date

=back

=cut

my $help = 0;
my $start_date;

GetOptions(
    'help|?'  => \$help,
    'man'     => \$help,
    'start=s' => \$start_date
    ) or pad2usage(2);
pod2usage(2) if $help;

my $plugin = Koha::Plugin::Com::ByWaterSolutions::Bibliotheca->new();
my $limit = 50; #FIXME make option instead of hardcoded
my $offset = 1;

while( $plugin->fetch_records({start_date=> $start_date, offset=>$offset, limit=>$limit}) ){
  $offset += $limit;
};

