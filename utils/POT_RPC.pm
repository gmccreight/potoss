package POT_RPC;

use strict;
use warnings;
use Carp;

use LWP::Simple qw(get);
use HTTP::Request::Common;
use LWP::UserAgent;

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

sub set_site_url {
    my $self = shift;
    $self->{site_url} = shift;

    if ($self->{site_url} !~ /^http/i) {
        croak("the site_url should have http at the beginning");
    }
}

sub get_page_plain_text {
    my $self = shift;
    my $page_name = shift || croak("need page_name");
    my $base = $self->{site_url} || croak("site_url not set yet");
    return get("$base/?PH_plain&nm_page=$page_name");
}

sub post_page_plain_text {
    my $self = shift;
    my $page_name = shift || croak("need page name");
    my $plain_text = shift;

    my $base = $self->{site_url} || croak("site_url not set yet");

    # Get the HEAD revision number for use when posting.
    my $edit_page_text = get("$base/?PH_edit&nm_page=$page_name&nm_rev=HEAD");

    if ($edit_page_text =~ /number_at_edit_start" value="([0-9]+)"/) {
        
    }
    else {
        croak("could not get HEAD version number by scraping the edit page.  Text is: $edit_page_text");
    }

    my $head_revision_num = $1;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->request(POST "$base/?$page_name",
        [PH_page_submit => 1, nm_page => $page_name, nm_text => $plain_text,
        nm_head_revision_number_at_edit_start => $head_revision_num]);

    my $results = '';

    if ($response->is_success) {
        $results = $response->content;
    }
    else {
        $results = $response->error_as_HTML;
    }

    return $results;

}

sub append_to_page {
    my $self = shift;
    my $page_to_append_to = shift || croak("need page to append to");
    my $text_to_append = shift || croak("need text to append");

    # Append a link to the new page to a pre-existing page
    my $text = $self->get_page_plain_text($page_to_append_to);
    $text .= $text_to_append;
    return $self->post_page_plain_text($page_to_append_to, $text);
}

1;