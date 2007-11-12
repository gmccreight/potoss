#!/usr/bin/perl

# This very simple CGI script will create a new page and add that page
# as a link to a pre-existing page, thus adding it to the pre-existing
# page's link tree.

use strict;
use warnings;

use CGI qw(:all);
use LWP::Simple qw(get);

require POT_RPC;

print header();

# If there's an exception thrown in a module, display it in the web page
# so it will be easier to debug from the web interface.
$SIG{__DIE__} = sub { my_die($_[0]); };

main();

sub main {

    my $page_to_append_link_to = param('nm_append_to_page') || '';
    my $site_url_minus_http = param('nm_site_url') || 'www.pageoftext.com';
    my $site_url = "http://" . $site_url_minus_http;

    my $prpc = POT_RPC->new();
    $prpc->set_site_url($site_url);

    # form used in two places.
    my $form = qq~
        <form method="post" action="./pot_add.cgi">
        <div style="margin-bottom:10px;">
            <input type="text" name="nm_site_url" value="$site_url_minus_http" style="width:240px;"> - POT site url
            <span style="background-color:#fee; margin-left:10px;">no http:// and no trailing slash.  Can be set in URL using <strong>nm_site_url=www.potblah.com</strong></span>
        </div>
        <div style="margin-bottom:10px;">
            <input type="text" name="nm_append_to_page" value="$page_to_append_link_to" style="width:240px;"> - Page to append link to
            <span style="background-color:#fee; margin-left:10px;">can be set in URL using <strong>nm_append_to_page=some_page_name</strong></span>
        </div>
        <div style="margin-bottom:10px;">
            <input type="text" id="myel_new_page_name" name="nm_new_page_name" value="" style="width:240px;"> - New page name
        </div>
        <input type="submit" name="" value="add new page" class="form">
        </form>
    ~;

    if (! param('nm_new_page_name') ) {
        my $body = qq~
            <h4>Add a new page and append a link to the bottom of a pre-defined page</h4>
            $form
        ~;
        hprint($body);
    }
    else {

        my $new_page_name = param('nm_new_page_name');
        
        if (! $page_to_append_link_to) {
            my_die("need a page to append link to");
        }

        # Check that the page to add link to exists
        {
            my $results = get("$site_url/?$page_to_append_link_to");

            #it didn't work...
            if ($results !~ /edit this page/) {
                my_die("page $page_to_append_link_to does not exist, so it cannot be appended to.");
            }
        }

        # Make sure that the page you're adding links to will show outgoing links
        {
            my $results = get("$site_url/?PH_page_opts&nm_page=$page_to_append_link_to&nm_level=more&nm_has_linking=yes");

            #it didn't work...
            if ($results !~ m{links to other pages will now be <strong>visible</strong>}) {
                my_die($results);
            }
        }

        # Create the new page
        {
            my $results = get("$site_url/?PH_create_submit&nm_page=$new_page_name");

            #it didn't work...
            if ($results !~ /Congratulations, you've created a new page/) {
                my_die($results);
            }
        }


        # Allow incoming links
        {
            my $results = get("$site_url/?PH_page_opts&nm_page=$new_page_name&nm_level=more&nm_allows_incoming_links=yes");

            #it didn't work...
            if ($results !~ /Other pages may now link/) {
                my_die($results);
            }
        }

        # Append the link to the new page to another page.
        {
            my $results = $prpc->append_to_page($page_to_append_link_to, "\n[$new_page_name]");

            #it didn't work (302 Found means it *did* work)
            if ($results !~ /302 Found/) {
                my_die($results);
            }
        }

        my $body = qq~
            <div style="background-color:#eee;margin-top:20px;padding:4px;margin-bottom:6px;">Success!</div>

            <ul>
                <li> Added page <span style="color:#393;">$new_page_name</span> </li>
                <li> Made page <span style="color:#393;">$new_page_name</span> linkable </li>
                <li> Appended a link to page <span style="color:#393;">$new_page_name</span> to the bottom of page <span style="color:#393;">$page_to_append_link_to</span> </li>
                <li style="margin-top:16px;"> <a href="$site_url/?PH_edit&nm_page=$new_page_name&nm_rev=HEAD">edit <span style="color:#393;">$new_page_name</span> </a> </li>
                <li style="margin-top:6px;"> <a href="$site_url/?PH_page_links&nm_page=$page_to_append_link_to&nm_sort_by=modified">view link tree for <span style="color:#393;">$page_to_append_link_to</span> </a> </li>
            </ul>

            <div style="background-color:#eee;margin-top:40px;padding:4px;margin-bottom:6px;">Add another page?</div>
            $form
        ~;

        hprint($body);

    }

}

sub my_die {
    my $error = shift;
    $error = qq~<h2>POT ADD ERROR:</h2>\n~ . $error;
    hprint($error);
    exit;
}

sub hprint {
    my $body = shift;
    print qq~
        <html>
            <head>
                <style>
                body{margin:10px;padding:0;font: normal 11px verdana;color:#444;}
                td{font: normal 11px verdana;color:#444;}
                .form{font: normal 11px verdana;color:#444;}
                a{color:#666;}
                </style>
                
                <script>
                    function do_onload () {
                        if ( document.getElementById('myel_new_page_name') ) {
                            document.getElementById('myel_new_page_name').focus();
                        }
                    }
                </script>
            </head>
            <body onload="do_onload()">
                $body
            </body>
        </html>
    ~;
}