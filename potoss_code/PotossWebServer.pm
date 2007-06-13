package PotossWebServer;

use HTTP::Server::Simple::CGI;
use HTTP::Server::Simple::Static;
use IO::Capture::Stdout;
use base qw( HTTP::Server::Simple::CGI HTTP::Server::Simple::Static );

use strict;
use warnings;

sub handle_request {
    my($self, $cgi) = @_;

    if ($ENV{REQUEST_URI} =~ /\.(gif|png|css|js)/) {
        $self->serve_static($cgi, ".");
    }
    else {
        eval {
            require Potoss;
            Potoss::main($cgi, {CNF_SHOULD_STRIP_QUESTION_MARKS => 0});
        };
    }
}

1;