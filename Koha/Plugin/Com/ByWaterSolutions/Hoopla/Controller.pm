package Koha::Plugin::Com::ByWaterSolutions::Hoopla::Controller;

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use Koha::Plugin::Com::ByWaterSolutions::Hoopla;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json);
use Encode qw(encode_utf8);

use CGI;
use Try::Tiny;

=head1 Koha::Plugin::Com::ByWaterSolutions::Hoopla::Controller
A class implementing the controller code for Hoopla requests
=head2 Class methods
=head3 search
Method to search the library's Hoopla collection
=cut

sub search {
    my $c = shift->openapi->valid_input or return;

    my $query   = $c->validation->param('query');

    return try {
        my $plugin   = Koha::Plugin::Com::ByWaterSolutions::Hoopla->new();
        warn $query;
        my $results = $plugin->search( $query );

        return $c->render(
            status => 200,
            json   => $results
        );
    }
    catch {
        return $c->render(
            status  => 500,
            openapi => { error => "Unhandled exception ($_)" }
        );
    };
}

sub details {
    my $c = shift->openapi->valid_input or return;

    my $content_id = $c->validation->param('content_id');

    return try {
        my $plugin   = Koha::Plugin::Com::ByWaterSolutions::Hoopla->new();
        warn $content_id;
        my $details = $plugin->details( $content_id );

        return $c->render(
            status => 200,
            json   => $details
        );
    }
    catch {
        return $c->render(
            status  => 500,
            openapi => { error => "Unhandled exception ($_)" }
        );
    };
}

sub status {
    my $c = shift->openapi->valid_input or return;

    my $patron = $c->stash('koha.user');

    unless( $patron ){
        return $c->render(
            status => 403,
            error => {"not_signed_in"}
        );
    }
    return try {
        my $plugin   = Koha::Plugin::Com::ByWaterSolutions::Hoopla->new();
        my $status = $plugin->status( $patron->cardnumber );

        return $c->render(
            status => 200,
            json   => $status
        );
    }
    catch {
        return $c->render(
            status  => 500,
            openapi => { error => "Unhandled exception ($_)" }
        );
    };
}


1;
