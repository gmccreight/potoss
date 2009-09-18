#!/usr/bin/perl

# This script helps to facilitate using a normal text editor with
# a potoss installation.

use strict;
use warnings;

#use LWP::Debug qw(+);
use HTTP::Request::Common;
use LWP::Simple;

my $SITE_URL = "http://www.pageoftext.com";
my $DEFAULT_FILE_PREFIX = "pot_7898_";

my $operation = $ARGV[0] || die "need operation as second argument";
my $page = $ARGV[1] || die "need page name as first argument";
my $filename = $ARGV[2] || "";


if ($operation eq "get") {
    get_page($page, $filename);
}
elsif ($operation eq "post") {
    post_page($page, $filename);
}
else {
    die "operation $operation is not supported.  Only get and post";
}

# Get a page from the potoss server
# If a filename is supplied as the second argument, then get the
# data in that file rather than trying to infer a filename from the
# page name.
sub get_page {
    my $page_name = shift;
    die "need page_name" if ! $page_name;

    my $filename = "$DEFAULT_FILE_PREFIX$page_name.txt";
    $filename = shift || $filename;

    my $data = get("$SITE_URL/PH_plain&nm_page=$page_name");
    _write_file($filename, $data);
}

# Post a page to the potoss server
# If a filename is supplied as the second argument, then post the
# data in that file rather than trying to infer a filename from the
# page name.
sub post_page {

    my $page_name = shift;
    die "need page_name" if ! $page_name;

    my $filename = "$DEFAULT_FILE_PREFIX$page_name.txt";
    $filename = shift || $filename;
    die "file not found" if ! -e $filename;

    my $data = _read_file($filename);
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;

    my $response = $ua->post("$SITE_URL/?$page_name",
        [PH_page_submit => 1, nm_page => $page_name,
         nm_text => $data, nm_skip_revision_num_check => 1 ]);

    # Also... if you're trying to debug,
    # uncomment the "use LWP::Debug qw(+);" line up at the top of this script
    #if ($response->is_success) {
    #    print $response->content;
    #}
    #else {
    #    print $response->error_as_HTML;
    #}

}

sub _read_file {
    # [tag:easy_install:gem] - We don't use File::Slurp to avoid prereqs
    my $filename = shift;
    open(my $fh, "<", $filename)
        || die "Cannot read from file $filename - $!";
    my @lines = <$fh>;
    close($fh)
        || die "could not close $filename after reading";
    return join("", @lines);
}

sub _write_file {
    # [tag:easy_install:gem] - We don't use File::Slurp to avoid prereqs
    my $filename = shift;
    my $data = shift;
    open(my $fh, ">", $filename)
        || die "Cannot write to file $filename - $!";
    print $fh $data;
    close($fh)
        || die "could not close $filename after writing";
}
