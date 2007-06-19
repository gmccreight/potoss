package HTTP::Server::Simple::Mason;
use base qw/HTTP::Server::Simple::CGI/;
use strict;
our $VERSION = '0.09';

=head1 NAME

HTTP::Server::Simple::Mason - An abstract baseclass for a standalone mason server


=head1 SYNOPSIS


	my $server = MyApp::Server->new();
	
	$server->run;
	
	package MyApp::Server;
	use base qw/HTTP::Server::Simple::Mason/;
	
	sub mason_config {
	    return ( comp_root => '/tmp/mason-pages' );
	}

=head1 DESCRIPTION


=head1 INTERFACE

See L<HTTP::Server::Simple> and the documentation below.

=cut



use HTML::Mason::CGIHandler;
use HTML::Mason::FakeApache;

use Hook::LexWrap;

wrap 'HTML::Mason::FakeApache::send_http_header', pre => sub {
    my $r = shift;
    my $status = $r->header_out('Status') || '200 H::S::Mason OK';
    print STDOUT "HTTP/1.0 $status\n";
};

=head2 mason_handler 

Returns the server's C<HTML::Mason::CGIHandler> object.  The first time
this method is called, it creates a new handler by calling C<new_handler>.

=cut

sub mason_handler {
    my $self = shift;
    $self->{'mason_handler'} ||= $self->new_handler;
    return $self->{'mason_handler'};
}

=head2 handle_request CGI

Called with a CGI object. Invokes mason and runs the request

=cut

sub handle_request {
    my $self = shift;
    my $cgi  = shift;

    if (
        ( !$self->mason_handler->interp->comp_exists( $cgi->path_info ) )
        && (
            $self->mason_handler->interp->comp_exists(
                $cgi->path_info . "/index.html"
            )
        )
      )
    {
        $cgi->path_info( $cgi->path_info . "/index.html" );
    }

    eval { my $m = $self->mason_handler;

        $m->handle_cgi_object($cgi) };

    if ($@) {
        my $error = $@;
        $self->handle_error($error);
    } 
}

=head2 handle_error ERROR

If the call to C<handle_request> dies, C<handle_error> is called with the
exception (that is, C<$@>).  By default, it does nothing; it can be overriden
by your subclass.

=cut

sub handle_error {
    my $self = shift;

    return;
} 

=head2 new_handler

Creates and returns a new C<HTML::Mason::CGIHandler>, with configuration
specified by the C<default_mason_config> and C<mason_config> methods.
You don't need to call this method yourself; C<mason_handler> will automatically
call it the first time it is called.

=cut

sub new_handler {
    my $self    = shift;
    
    my $handler_class = $self->handler_class;

    my $handler = $handler_class->new(
        $self->default_mason_config,
        $self->mason_config,
   # Override mason's default output method so 
   # we can change the binmode to our encoding if
   # we happen to be handed character data instead
   # of binary data.
   # 
   # Cloned from HTML::Mason::CGIHandler
    out_method => 
      sub {
            my $m = HTML::Mason::Request->instance;
            my $r = $m->cgi_request;
            # Send headers if they have not been sent by us or by user.
            # We use instance here because if we store $request we get a
            # circular reference and a big memory leak.
                unless ($r->http_header_sent) {
                       $r->send_http_header();
                }
            {
            $r->content_type || $r->content_type('text/html; charset=utf-8'); # Set up a default

            if ($r->content_type =~ /charset=([\w-]+)$/ ) {
                my $enc = $1;
                binmode *STDOUT, ":encoding($enc)";
            }
            # We could perhaps install a new, faster out_method here that
            # wouldn't have to keep checking whether headers have been
            # sent and what the $r->method is.  That would require
            # additions to the Request interface, though.
             print STDOUT grep {defined} @_;
            }
        },
        @_,
    );

    $self->setup_escapes($handler);

    return ($handler);
}

=head2 handler_class

Returns the name of the Mason handler class invoked in C<new_handler>.  Defaults
to L<HTML::Mason::CGIHandler>, but in your subclass you may wish to change it to a
subclass of L<HTML::Mason::CGIHandler>.

=cut

sub handler_class { "HTML::Mason::CGIHandler" }

=head2 setup_escapes $handler

Sets up the Mason escapes for the handler C<$handler>.  For example, the C<h> in

  <% $name | h %>

By default, sets C<h> to C<HTTP::Server::Simple::Mason::escape_utf8>
and C<u> to C<HTTP::Server::Simple::Mason::escape_uri>, but you can override this in your subclass.

=cut

sub setup_escapes {
    my $self = shift;
    my $handler = shift;

    $handler->interp->set_escape(
        h => \&HTTP::Server::Simple::Mason::escape_utf8 );
    $handler->interp->set_escape(
        u => \&HTTP::Server::Simple::Mason::escape_uri );
    return;
} 

=head2 mason_config

Returns a subclass-defined mason handler configuration; you almost certainly want to override it
and specify at least C<comp_root>.

=cut

sub mason_config {
    (); # user-defined
}

=head2 default_mason_config

Returns the default mason handler configuration (which can be overridden by entries in C<mason_config>).

=cut

sub default_mason_config {
    (
        default_escape_flags => 'h',

        # Turn off static source if we're in developer mode.
        autoflush => 0
    );
}

# {{{ escape_utf8

=head2 escape_utf8 SCALARREF

does a css-busting but minimalist escaping of whatever html you're passing in.

=cut

sub escape_utf8 {
    my $ref = shift;
    my $val = $$ref;
    use bytes;
    $val =~ s/&/&#38;/g;
    $val =~ s/</&lt;/g;
    $val =~ s/>/&gt;/g;
    $val =~ s/\(/&#40;/g;
    $val =~ s/\)/&#41;/g;
    $val =~ s/"/&#34;/g;
    $val =~ s/'/&#39;/g;
    $$ref = $val;
    Encode::_utf8_on($$ref);

}

# }}}

# {{{ escape_uri

=head2 escape_uri SCALARREF

Escapes URI component according to RFC2396

=cut

use Encode qw();

sub escape_uri {
    my $ref = shift;
    $$ref = Encode::encode_utf8($$ref);
    $$ref =~ s/([^a-zA-Z0-9_.!~*'()-])/uc sprintf("%%%02X", ord($1))/eg;
    Encode::_utf8_on($$ref);
}

# }}}



=head1 CONFIGURATION AND ENVIRONMENT

For most configuration, see L<HTTP::Server::Simple>.

You can (and must) configure your mason CGI handler by subclassing this module and overriding
the subroutine C<mason_config>. It's most important that you set a component root (where your pages live)
by adding 

    comp_root => '/some/absolute/path'

See the Synopsis section or C<ex/sample_server.pl> in the distribution for a complete example.


=head1 DEPENDENCIES


L<HTTP::Server::Simple>
L<HTML::Mason>

=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS


Please report any bugs or feature requests to
C<bug-http-server-simple-mason@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Jesse Vincent C<< <jesse@bestpractical.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2001-2005, Jesse Vincent  C<< <jesse@bestpractical.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut


1;
