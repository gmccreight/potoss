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

use PotossWebServer;

my $server = PotossWebServer->new($port);
$server->run();