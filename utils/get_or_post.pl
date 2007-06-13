#!/usr/bin/perl

# This script helps to facilitate using a normal text editor with
# a potoss installation.  It's not really fully usable yet, but when it is
# done you'll be able to use a potoss installation just like you would use
# a local data store.

use strict;
use warnings;
use HTTP::Request::Common;
use LWP::Simple;

my $SITE_URL = "http://www.some_potoss_site.com";
my $FILE_PREFIX = "pot_7898_";

get_page("lwp_test");
post_page("lwp_test");

sub get_page {
    my $page_name = shift;
    die "need page_name" if ! $page_name;
    my $data = get("$SITE_URL/PH_plain&nm_page=$page_name");
    _write_file("$FILE_PREFIX$page_name.txt", $data);
}

sub post_page {
    my $page_name = shift;
    die "need page_name" if ! $page_name;
    my $filename = "$FILE_PREFIX$page_name.txt";
    die "file not found" if ! -e $filename;
    my $data = _read_file($filename);
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request(POST '$SITE_URL/?$page_name', [PH_page_submit => 1, nm_page => $page_name, nm_text => $data]);

#    if ($response->is_success) {
#        print $response->content;
#    }
#    else {
#        print $response->error_as_HTML;
#    }

}

sub _read_file {
    # [tag:easy_install] - We don't use File::Slurp to avoid prerequisites
    my $filename = shift;
    open(my $fh, "<", $filename)
        || die "Cannot read from file $filename - $!";
    my @lines = <$fh>;
    close($fh)
        || die "could not close $filename after reading";
    return join("", @lines);
}

sub _write_file {
    # [tag:easy_install] - We don't use File::Slurp to avoid prerequisites
    my $filename = shift;
    my $data = shift;
    open(my $fh, ">", $filename)
        || die "Cannot write to file $filename - $!";
    print $fh $data;
    close($fh)
        || die "could not close $filename after writing";
}