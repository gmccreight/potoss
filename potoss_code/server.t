#!/usr/bin/perl

use strict;
use warnings;

use lib qw(potoss_code);

# unbuffer the output.
$| = 1;

chdir("../");

require PotConf;

no warnings;
# Share the configuration
our %conf = %PotConf::conf;
use warnings;

my $port = $conf{CNF_HTTP_SERVER_PORT}
    || die "could not read the configuration of the port";

my $child_pid = undef;

unless ( $child_pid = fork() ) {
    exec("cd potoss_code; perl run_test_web_server.pl");
    exit 0;
}

sleep 2;

use Test::More tests => 57;

use Test::WWW::Mechanize;
my $mech = Test::WWW::Mechanize->new();

require BrowserTestBase;
my $test_base_obj = BrowserTestBase->new($mech);

my $dir = "http://localhost:$port/?";

$test_base_obj->runtests($dir);

#kill the server by sending it a special command
$mech->get( $dir . "kill_server");
