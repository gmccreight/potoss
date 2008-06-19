package PotossWebServer;

use lib qw(patched_libs);

# [tag:easy_install:gem]
# Don't make the person install all the needed modules.  Give them default
# ones which work OK.
# Push this directory onto the end, so it's the last one that is checked.
# It's the fallback if you don't have the modules already installed on
# your system.  If you do, your system will use those.

BEGIN { push(@INC, qw(fallback_libs)); }

use HTTP::Server::Simple::CGI;
use HTTP::Server::Simple::Static;
use base qw( HTTP::Server::Simple::CGI HTTP::Server::Simple::Static );

use strict;
use warnings;

sub handle_request {
    my($self, $cgi) = @_;

    if ($ENV{REQUEST_URI} =~ /kill_server$/) {
        exit 0;
    }
    elsif ($ENV{REQUEST_URI} =~ /\.(gif|png|jpg|css|js)$/) {
        $self->serve_static($cgi, ".");
    }
    else {

        eval {
            require Potoss;
            Potoss::main($cgi, {CNF_SHOULD_STRIP_QUESTION_MARKS => 0});
        };

        warn $@ if $@;

    }
}

1;
