# Use the same tests from both
# Selenium and Test::WWW::Mechanize
package BrowserTestBase;

use strict;
use warnings;
use Test::More;

require PotConf;

no warnings;
# Share the configuration because the .t file uses it as well.
our %conf = %PotConf::conf;
use warnings;

sub new {
    my ( $proto, $browser_obj ) = @_;
    my $class = ref($proto) || $proto;

    my $self = {};
    bless( $self, $class );

    $self->set_browser( $browser_obj );

    return $self;
}

sub set_browser {
    my $self = shift;
    my $browser = shift;

    $self->{BROWSER} = $browser;

    if ( ref($browser) =~ m{WWW::Mechanize} ) {
        $self->{TYPE} = 'mech';
    }
    else {
        $self->{TYPE} = 'sel';
    }
}

sub open_ok {
    my $self = shift;
    my $url = shift;
    my $message = shift || "open_ok - $url";

    if ($self->{TYPE} eq 'mech') {
        $self->{BROWSER}->get_ok( $url, $message );
    }
    else {

    }
}

sub is_text_present_ok {
    my $self = shift;
    my $text = shift;

    if ($self->{TYPE} eq 'mech') {
        #warn $self->{BROWSER}->response()->content();
        $self->{BROWSER}->content_contains( $text, "is_text_present_ok - $text" );
    }
    else {

    }
}

sub click_ok {
    my $self = shift;
    my $link = shift;

    $link =~ s{\A (link|id)=}{}xms;

    my $link_type = $1 || '';

    if ($self->{TYPE} eq 'mech') {
        if ($link_type eq 'link') {
            $self->{BROWSER}->follow_link_ok( { text => $link }, "click_link_ok - $link" );
        }
        elsif ($link_type eq 'id') {
            $self->mech_click_link_with_id_ok($self->{BROWSER}, $link);
        }
        else {
            if ($link eq 'nm_submit') {
                ok($self->{BROWSER}->submit(), "mech submitted ok");
            }
        }
    }
    else {

    }
}

sub my_loads_ok {
    my $self = shift;
    # this is called so often that it should be a subroutine
    # with a cleaner name and a variable you can change in one place.

    if ($self->{TYPE} eq 'mech') {
        ok($self->{BROWSER}->success(), "mech load page success");
    }
    else {
        $self->{BROWSER}->wait_for_page_to_load_ok('30000', 'page loads in less than 30000');
    }
}

sub type_ok {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    if ($self->{TYPE} eq 'mech') {
        ok($self->mech_fill_form_input($name, $value), "mech type_ok for input $name");
    }
    else {
    }
}

sub add_nbsps {
    # The text uses &nbsp; characters to display without line breaks.
    # When seen in a browser, these look just like spaces, but using
    # WWW::Mechanize, they look like &nbsp; characters.  So, we need to
    # differentiate between the two browsers when testing this.
    my $self = shift;
    my $text = shift;

    if ($self->{TYPE} eq 'mech') {
        $text =~ s{ }{&nbsp;}g;
        return $text;
    }
    else {
        return $text;
    }
}

sub mech_click_link_with_id_ok {
    # There doesn't appear to be a built-in way of telling the mech
    # to click on a link with a given id, so I had to create this method.
    my $self = shift;
    my $mech = shift;
    my $id = shift;

    my $message = "opened from link click on id: $id";

    my @links = $mech->find_all_links( tag => "a" );
    for my $link (@links) {
        my $attrs = $link->attrs();
        if (defined($attrs->{id}) && $attrs->{id} eq $id) {
            $self->open_ok($link->url(), $message);
            return;
        }
    }

    # it failed to find and click on the id.
    ok(0, $message);
}

sub mech_fill_form_input {
    my $self = shift;
    my $name = shift;
    my $value = shift;

    my @fields = ($name);

    $self->{BROWSER}->form_with_fields( @fields )
        || die "could not get a single form matching field $name";

    $self->{BROWSER}->field( $name, $value );

    return 1;

}

sub runtests {
    
    my $self = shift;
    my $dir = shift;

    # To make it easy to write tests using the Selenium IDE, we'll use
    # exactly what it outputs here.  Including the $sel-> part, which we'll
    # need to add the following assignment for:
    my $sel = $self;

    $sel->open_ok("${dir}potoss_saved_test");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("edit this page");
    $sel->is_text_present_ok($self->add_nbsps("this is change 11"));


    $sel->click_ok("link=advanced options");
    $sel->my_loads_ok();
    $sel->click_ok("link=show the page's revision history");
    $sel->my_loads_ok();
    $sel->click_ok("link=compare two revisions");
    $sel->my_loads_ok();
    $sel->click_ok("link=start at revision 9");
    $sel->my_loads_ok();
    $sel->click_ok("link=end at revision 10");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("this is change 10");


    $sel->open_ok("${dir}potoss_saved_test");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("edit this page");
    $sel->click_ok("id=myel_edit_link");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("Use just plain text");


    $sel->open_ok("${dir}potoss_wow"); #read only alias for potoss_saved_test
    $sel->my_loads_ok();
    $sel->is_text_present_ok("read only");
    $sel->is_text_present_ok($self->add_nbsps("this is change 11"));

    $sel->open_ok("${dir}PH_edit&nm_page=potoss_wow");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("You can't edit this page");

    $sel->open_ok("${dir}PH_page_opts&nm_page=potoss_wow");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("You can't view this page's options");

    $sel->open_ok("${dir}potoss_tmp_test");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("This page doesn't exist");
    $sel->click_ok("link=create it as a new page");
    $sel->my_loads_ok();
    $sel->click_ok("id=myel_new_page");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("edit this page");
    $sel->click_ok("link=edit this page");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("This message only appears the first time you edit a page");
    $sel->type_ok("nm_text", "This is some text.");
    $sel->click_ok("nm_submit");
    $sel->my_loads_ok();
    $sel->is_text_present_ok($self->add_nbsps("This is some text"));
    $sel->click_ok("link=edit this page");
    $sel->my_loads_ok();
    $sel->type_ok("nm_text", "This is some text.\nThis is even more text.");
    $sel->click_ok("nm_submit");
    $sel->my_loads_ok();
    $sel->is_text_present_ok($self->add_nbsps("This is even more text"));
    $sel->click_ok("link=advanced options");
    $sel->my_loads_ok();
    $sel->click_ok("link=show the page's revision history");
    $sel->my_loads_ok();
    $sel->is_text_present_ok("view revision 2");

    # Remove the file you just created.
    `cd $conf{CNF_TEXTS_DIR} ; rm -r potoss_tmp_test_REVS ; rm potoss_tmp_test*`;

#    #-------------------------------------------------------------------------
#    # Story:
#    # When there is only a single revision, a message appears when you try
#    # to look at the revisions.
#
#    $sel->open_ok("${dir}potoss_tmp_test");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("This page doesn't exist");
#    $sel->click_ok("link=create it as a new page");
#    $sel->my_loads_ok();
#    $sel->click_ok("id=myel_new_page");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("edit this page");
#    $sel->click_ok("link=edit this page");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("This message only appears the first time you edit a page");
#    $sel->type_ok("myel_text_area", "This is some text.");
#    $sel->click_ok("nm_submit");
#    $sel->my_loads_ok();
#    $sel->click_ok("link=advanced options");
#    $sel->my_loads_ok();
#    $sel->click_ok("link=show the page's revision history");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("There is currently only one revision");
#
#    `cd $texts_dir ; rm -r potoss_tmp_test_REVS ; rm potoss_tmp_test*`;
#
#    #-------------------------------------------------------------------------
#    # Story:
#    # Try to create a page name which is in the dictionary
#    $sel->open_ok("${dir}PH_create");
#    $sel->is_text_present_ok("like the page name");
#    $sel->type_ok("myel_page_name", "queen");
#    $sel->click_ok("nm_submit");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("is in the dictionary");
#
#    #-------------------------------------------------------------------------
#    # Story:
#    # Try to create a page which already exists
#    $sel->open_ok("${dir}PH_create");
#    $sel->is_text_present_ok("like the page name");
#    $sel->type_ok("myel_page_name", "potoss_saved_test");
#    $sel->click_ok("nm_submit");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("that one already exists");
#
#    #-------------------------------------------------------------------------
#    # Story:
#    # Try to create a wrong page name.  It will automatically suggest a
#    # better one.
#    $sel->open_ok("${dir}PH_create");
#    $sel->is_text_present_ok("like the page name");
#    $sel->type_ok("myel_page_name", "My dog is always hungry!");
#    $sel->click_ok("nm_submit");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("changed the page name to");
#    $sel->is_text_present_ok("my_dog_is_always_hungry");
#
#    #-------------------------------------------------------------------------
#    # Story:
#    # A user wants to encrypt and decrypt their page content.
#
#    $sel->open_ok("${dir}potoss_test_encryption_a");
#    $sel->is_text_present_ok("Here is some unencrypted content.");
#    $sel->is_text_present_ok("Less than < and greater than > and ampersand & and question mark ?");
#    $sel->click_ok("link=advanced options");
#    $sel->my_loads_ok();
#    $sel->click_ok("link=very advanced");
#    $sel->my_loads_ok();
#    $sel->click_ok("link=show the encryption buttons");
#    $sel->my_loads_ok();
#    $sel->click_ok("link=go back to the page");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("Here is some unencrypted content.");
#    $sel->click_ok("myel_edit_link");
#    $sel->my_loads_ok();
#    ok($sel->get_value("myel_text_area") =~ /^Here is some unencrypted content/);
#    ok($sel->get_value("myel_text_area") =~ /Less than < and greater than > and ampersand & and question mark \?/);
#    $sel->type_ok("myel_blowfish_key", "asimplekey");
#    $sel->click_ok("link=encrypt");
#    ok($sel->get_value("myel_text_area") =~ /^4BE6B52958CAF3FA48780A3D72959F9DC87/);
#    $sel->click_ok("link=decrypt");
#    ok($sel->get_value("myel_text_area") =~ /^Here is some unencrypted content/);
#    ok($sel->get_value("myel_text_area") =~ /Less than < and greater than > and ampersand & and question mark \?/);
#    #go back to the main page
#    $sel->click_ok("//input[\@value='cancel']");
#    my_wait_until_text_present_ok("advanced options", 1);
#    $sel->click_ok("link=advanced options");
#    $sel->my_loads_ok();
#    $sel->click_ok("link=very advanced");
#    $sel->my_loads_ok();
#    $sel->click_ok("link=hide the encryption buttons");
#    $sel->my_loads_ok();
#
#    #-------------------------------------------------------------------------
#    # Story:
#    # A user decides to edit starting at a non-HEAD revision.
#    # There should be alerts about this, but they should be able to get to
#    # the right place to edit, and if they cancel their edit, it should take
#    # them back to the page on the right revision.
#
#    $sel->open_ok("/?PH_edit&nm_page=potoss_saved_test&nm_rev=9");
#    $sel->is_text_present_ok("You are not editing the latest revision");
#    $sel->click_ok("link=Edit the latest revision");
#    $sel->my_loads_ok();
#    $sel->click_ok("//input[\@value='cancel']");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("edit this page");
#
#    $sel->click_ok("myel_edit_link");
#    $sel->my_loads_ok();
#    $sel->click_ok("//input[\@value='cancel']");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("edit this page");
#
#    $sel->open_ok("/?PH_edit&nm_page=potoss_saved_test&nm_rev=9");
#    $sel->click_ok("//input[\@value='cancel']");
#    $sel->my_loads_ok();
#    $sel->is_text_present_ok("You are looking at revision 9");

}

1;

