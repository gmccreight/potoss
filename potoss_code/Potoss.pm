package Potoss;

# POTOSS (The source of pageoftext.com)

use strict;
use warnings;

#use Time::HiRes qw(tv_interval gettimeofday);

require PotConf;
require Potoss::File;

no warnings;
# Share the configuration because the .t file uses it as well.
our %conf = %PotConf::conf;
use warnings;

my $cgi;

my $should_use_colons = ( exists $conf{CNF_USE_COLONS_IN_URL}
            && $conf{CNF_USE_COLONS_IN_URL} == 1 ) ? 1 : 0;

sub main {
    $cgi = shift;

    # You can override the configuration variables from the arg_ref.
    my $arg_ref = shift || {};
    if ($arg_ref) {
        for my $key (keys %{$arg_ref}) {
            if (exists($conf{$key})) {
                $conf{$key} = $arg_ref->{$key};
            }
        }
    }

    if (! $cgi) {
        require CGI;
        $cgi = new CGI;
    }
    
    my @p = $cgi->param();

    
    if (scalar(@p) == 1) {
        
        if ( $should_use_colons ) {

            my $keyword = $cgi->param("keywords");
            if ( $keyword =~ /:/ ) {

                require Potoss::Router;
                my $router = Potoss::Router->new();

                $router->set_from_string($keyword);

                if ( $router->get_page() && $router->get_action() ) {
                    $cgi->param(-name => 'nm_page', -value => $router->get_page());
                    $cgi->param(-name => $router->get_action(), -value => 1);
                    push @p, $router->get_action();
                }
            }
            else {
                push @p, $cgi->param("keywords");
            }

        }
        else {
            push @p, $cgi->param("keywords");
        }
    }

    for my $param_key (@p) {

        if ($param_key =~ m{ \A PH_[a-z_0-9]+ \z }xms ){
            no strict qw(refs);

            # If a subroutine of the same name as the page handler exists, run it.
            if ( exists &$param_key ) {
                $param_key->();
            }
            else {
                _error("Page $param_key not found");
            }

            return;
        }
    }

    #handle one of the page names
    @p = $cgi->param();
    if (scalar(@p) == 1) {
        if ($cgi->param("keywords")){
            show_page($cgi->param("keywords"));
        }
        return;
    }

    homepage();
}

sub homepage {
    
    my $type_of_page = (exists $conf{CNF_DEFAULT_PAGE_FORMAT})
        ? $conf{CNF_DEFAULT_PAGE_FORMAT}
        : 'text';
    
    my $body = qq~
        <p>Welcome!</p>

        <a href="./?PH_create">create a new <span class="pot">page of $type_of_page</span></a> to edit by yourself or with others

        <p>or</p>

        <a href="./?PH_find">find a page I previously created</a>
    ~;
    hprint( $body, { special_page_name => "Welcome" } );
}

sub PH_help_with_find {
    my $body = qq~

        <p style="margin-bottom:20px;">This form will send an email to a real person ($conf{CNF_ADMIN_FULL_NAME}... that's me!)</p>

        <form id="fr_help_find" method="post" action="./?">
            <input type="hidden" name="PH_help_with_find_submit" value="1">
            
            <div style="margin-bottom:8px;">What is your email address?</div>
            <div style="margin-bottom:20px;"><input type="text" name="nm_from_address" value="" class="form" style="width:200px"></div>

            <div style="margin-bottom:8px;">Describe the page in detail (like you're describing your lost wallet, trying to convince $conf{CNF_ADMIN_FIRST_NAME} it's yours)  Include any keywords $conf{CNF_ADMIN_HE_OR_SHE} might look for, etc.</div>
            <textarea id="myel_text_area" name="nm_description" cols="80" rows="16" style="font-size:12px;"></textarea>

            <div><input type="submit" name="nm_submit" value="send it" class="form"></div>
        </form>
    ~;
    hprint($body, { special_page_name => "Find Help" } );
}

sub PH_help_with_find_submit {

    require Mail::Sendmail;

    my $body = '';

    my $from_address = $cgi->param("nm_from_address") || "";
    my $page_description = $cgi->param("nm_description") || "";

    my $message_body = $page_description;

    my %mail = (
      To		=> "$conf{CNF_ADMIN_EMAIL}",
      From		=> $from_address,
      Subject => "$conf{CNF_SITE_READABLE_NAME} - user needs help finding page",
      'X-Mailer' => "Mail::Sendmail version $Mail::Sendmail::VERSION",
    );

    {
        no warnings;
        $Mail::Sendmail::mailcfg{smtp} = ['smtp.sbcglobal.net'];
    }

    $mail{'mESSaGE : '} = $message_body;
    # cheat on the date:
    $mail{Date} = Mail::Sendmail::time_to_date( time() );

    if (Mail::Sendmail::sendmail(%mail)) {
        $body .= "The email was sent to $conf{CNF_ADMIN_FIRST_NAME}. $conf{CNF_ADMIN_HE_OR_SHE} will email you back at the email address you provided.\n<br>";
    }
    else {
        no warnings;
        $body .= "Error sending mail: $Mail::Sendmail::error<br>";
    }

    #$body .= "\n<br />\$Mail::Sendmail::log says:\n<br /><br /><br /><br />", $Mail::Sendmail::log;

    hprint($body, { special_page_name => "Find Help Emailed" } );
}

sub PH_find {
    my $message = shift || '';

    my $email_help_message = ($message)
        ? qq~<p style="margin-top:60px; background-color:#fee; padding:10px;">
            If you can't find the page, you can ask the site administrator for help using <a href="./?PH_help_with_find">this form</a>.
        </p>~
        : '';

    my $word_0 = $cgi->param("nm_word_0") || '';
    my $word_1 = $cgi->param("nm_word_1") || '';
    my $word_2 = $cgi->param("nm_word_2") || '';

    $message = ($message)
        ? qq~<div style="background-color:#fcc; margin-bottom:20px; padding:4px;">$message</div>~
        : qq~<p style="margin-bottom:10px;">Find your lost page:</p>~;

    my $body = qq~
        $message
        
        <form id="fr_find" method="post" action="./?">
            <input type="hidden" name="PH_find_submit" value="1">
            
            <div style="margin-bottom:8px;">What are three unique, alphanumeric words that are longer than four characters in the page's contents?</div>
            <div style="margin-bottom:10px;"><input type="text" name="nm_word_0" value="$word_0" class="form" style="width:100px"> <span style="background-color:#fcc; padding:2px;">cannot</span> be in dictionary</div>
            <div style="margin-bottom:10px;"><input type="text" name="nm_word_1" value="$word_1" class="form" style="width:100px"> <span style="background-color:#fcc; padding:2px;">cannot</span> be in dictionary</div>
            <div style="margin-bottom:10px;"><input type="text" name="nm_word_2" value="$word_2" class="form" style="width:100px"> <span style="background-color:#cfc; padding:2px;">may</span> be in dictionary</div>

            <div><input type="submit" name="nm_submit" value="Find It!" class="form"></div>
        </form>

        $email_help_message
    ~;
    hprint($body, { special_page_name => "Find Lost Page" } );
    
    # die here because this is sometimes called numerous times, or from other
    # subroutines which we don't want to return to.
    die;
}

sub PH_find_submit {

    my $was_slowed_down = _slow_down_if_more_guesses_than(5); #[tag:security:gem] [tag:privacy:gem]

    my @words = ();

    for my $num (0..2) {
        my $word = $cgi->param("nm_word_$num") || '';
        my $easy_position = $num + 1;
        PH_find("word $easy_position is empty") if ! $word;
        PH_find("word $easy_position, $word, contains non-alphanumeric characters") if $word !~ /^[a-zA-Z0-9]+$/xms;
        PH_find("word $easy_position, $word, is too short") if length($word) < 5;
        if ($num < 2) {
            PH_find("word $easy_position, $word, is in the dictionary") if _is_in_dictionary($word);
        }
        push @words, $word;
    }

    my %num_words = map({$_ => 1} @words);
    PH_find("some of the words are the same") if scalar(keys %num_words) < 3;
    
    my $NOT_ALNUM = "[^a-zA-Z0-9]*";

    my @pages = `cd $conf{CNF_TEXTS_DIR}; ls *_HEAD | xargs grep -il "$NOT_ALNUM$words[0]$NOT_ALNUM" | xargs grep -il "$NOT_ALNUM$words[1]$NOT_ALNUM" | xargs grep -il "$NOT_ALNUM$words[2]$NOT_ALNUM"`;

    if (scalar(@pages) < 1) {
        PH_find("No matches found.");
    }
    if (scalar(@pages) > 1) {
        PH_find("More than one page matches, so we can't reveal them.  Try refining your search.");
    }

    my $page = $pages[0];
    chomp($page); #page has a newline...
    $page =~ s/_HEAD$//;
    
    #[tag:security:gem] [tag:privacy:gem]
    if ( page_fopt($page, 'exists', "hide_from_find") ) {
        PH_find("A page which matches your search was found, but it has its 'hide from find' option set, so it can't be shown here.");
    }

    my $body = qq~
        A single matching page was found.  Click <a href="./?$page">here</a> to go to it.
    ~;

    hprint($body, { special_page_name => "Find Lost Page" } );
}

sub PH_create {
    my $page_name = $cgi->param("nm_page") || "";
    my $relate_to_page = $cgi->param("nm_relate_to_page") || "";
    my $linking_is_one_way = $cgi->param("nm_linking_is_one_way") || 0;
    my $add_search_box = $cgi->param("nm_add_search_box") || "";

    my $error = shift || '';
    my $page_name_for_form = shift || $page_name;
    if ($error) {
        $error = qq~
            <div style="color:red;margin-bottom:10px;background-color:#fdd; padding:6px;">$error</div>
        ~;
    }

    my $body = qq~
        $error
        <form id="fr_create" method="post" action="./?">
            <input type="hidden" name="PH_create_submit" value="1">
            <input type="hidden" name="nm_relate_to_page" value="$relate_to_page">
            <input type="hidden" name="nm_linking_is_one_way" value="$linking_is_one_way">
            <input type="hidden" name="nm_add_search_box" value="$add_search_box">
            
            <div style="margin-bottom:8px;">What would you like the page name to be? (may only contain a-z, 0-9, and underscores)</div>
            <div style="margin-bottom:8px;">Like: <span style="color:#448;margin-left:10px;margin-right:10px;">mom_birthday_2007</span> or <span style="color:#448;margin-left:10px;">meeting_notes_070305</span></div>
            <div style="margin-bottom:8px;">If you don't want strangers to look at and possibly edit your page,<br>name it something unique and non-guessable.</div>
            <div style="margin-bottom:10px;"><input id="myel_page_name" type="text" name="nm_page" value="$page_name_for_form" class="form" style="width:300px"> <a href="javascript:fill_in_name();">suggest a name</a></div>
            <div><input type="submit" name="nm_submit" value="create the page" class="form"></div>
        </form>
    ~;
    hprint($body, {add_create_page_js => 1, special_page_name => "Create" });
}

sub PH_create_from_page {
    my $page_name = $cgi->param("nm_page");
    my $should_show_more_options = $cgi->param("nm_show_more_options") || 0;

    if (! $page_name) {
        throw("this should only be reachable from a pre-existing page, but there's no page name.");
    }

    my $more_opts = '';
    if ($should_show_more_options) {
        $more_opts = qq~
            <p style="margin-left:10px; margin-top:30px;"><span style="font-weight:bold;">A related page - two way linking:</span>
                <a href="./?PH_create&nm_relate_to_page=$page_name&nm_add_search_box=both" style="margin-left:20px;">also add searchboxes</a>
                <a href="./?PH_create&nm_relate_to_page=$page_name" style="margin-left:20px;">don't add searchboxes</a>
            </p>
            <p style="margin-left:20px;">Links will be added between the new page and the pre-existing page you were just on.</p>
            <p style="margin-left:20px;">If you choose to also add search boxes, they will be added to the top of each page, and will let you search both pages, and any other linked pages, at the same time.</p>
            <p style="margin-left:20px;"><span style="color:red;">Note:</span> If you got all fancy and already added a link pointing to the new page you are about to create, good for you!  We won't add another one.</p>

            <p style="margin-left:10px; margin-top:30px;"><span style="font-weight:bold;">A related page - one way linking only:</span>
                <a href="./?PH_create&nm_relate_to_page=$page_name&nm_add_search_box=preexisting&nm_linking_is_one_way=1" style="margin-left:20px;">also add searchbox</a>
                <a href="./?PH_create&nm_relate_to_page=$page_name&nm_linking_is_one_way=1" style="margin-left:20px;">don't add searchbox</a>
            </p>
            <p style="margin-left:20px;">A link will be added from the pre-existing page to the new page, but <strong><em>not</em></strong> from the new page back to the pre-existing page.</p>
            <p style="margin-left:20px;">If you choose to also add the search box, it will be added to the top of the pre-existing page, but not the newly created page.  It will let you search both pages from the pre-existing page.</p>
            <p style="margin-left:20px;"><span style="color:red;">Note:</span> If you got all fancy and already added a link pointing to the new page you are about to create, good for you!  We won't add another one.</p>
        ~;
    }
    else {
        if ( ! _page_is_an_alias($page_name) ) {
            $more_opts = qq~
                <p style="margin-top:30px;"><a href="./?PH_create_from_page&nm_page=$page_name&nm_show_more_options=1">Show the advanced page creation options</a></p>
            ~;
        }
    }

    my $body = qq~
        <p style="margin-top:20px;">Create:</p>

        <p style="margin-left:10px;"><a href="./?PH_create">A new page that is unrelated to the one you were just on</a></p>
    
        $more_opts
        
    ~;
    hprint($body, { page_name => $page_name, sub_page_name => "create new page" } );
}

sub throw ($) {
    my $exception = shift;

    if ($ENV{POTOSS_THROW_DIES_WITH_MORE_INFO}) {
        # go into great detail about the error.
        # go ahead and use Carp.
        use Carp;
        confess($exception);
    }

    my $body = qq~
        <div style="color:red;margin-bottom:10px;">
            The website has had an error, the details of which are below.
        </div>
        <div>
            $exception
        </div>
    ~;
    hprint($body, { special_page_name => "Error" });

    # Abort the rest of the processing, but use "die" because it
    # allows the HTTP::Server::Simple to trap and continue running.
    die;
}

sub PH_create_submit {
    my $page_name = $cgi->param("nm_page");
    my $relate_to_page = $cgi->param("nm_relate_to_page") || "";
    my $linking_is_one_way = $cgi->param("nm_linking_is_one_way") || 0;
    my $add_search_box = $cgi->param("nm_add_search_box") || "";

    my $error = _check_page_name_is_ok($page_name);

    if ($error ne 'ok'){

        my $suggested_page_name = $page_name;
        if ($error =~ /may not contain/) {
            $suggested_page_name = normalize_page_name($page_name);
        }
        
        if ($suggested_page_name ne $page_name) {
            $error = qq~For technical reasons, we've changed the page name to:<p>$suggested_page_name</p>If that's ok, then you can continue, or, if you don't like the new name you can change it.~;
        }

        PH_create($error, $suggested_page_name);
        return;
    }

    if (_page_exists($page_name)) {
        my $error = qq~
            <p>Sorry, but that one already exists.  Please try another one.</p>
        ~;
        PH_create($error);
        return;
    }

    # If you want to relate the newly created page to a pre-existing page,
    # then $relate_to_page will be a page name.  If it's not a good page
    # name, you can throw an exception because it's an internal error or a
    # hacker and not a user error which we should provide a soft landing for.
    if ($relate_to_page) {
        my $error = _check_page_name_is_ok($relate_to_page);
        if ($error ne 'ok'){
            throw("the page to relate to, $relate_to_page, has a bad page name");
        }
        if (! _page_exists($relate_to_page) ) {
            throw("the page to relate to, $relate_to_page, does not exist");
        }
        if ( _page_is_an_alias($relate_to_page) ) {
            throw("you cannot relate a new page to a read-only alias page, $relate_to_page");
        }
    }    

    if ($relate_to_page) {

        if ( $linking_is_one_way ) {
            _write_new_page_revision($page_name, "");
        }
        else {
            _write_new_page_revision($page_name, "back to [$relate_to_page]");
        }   

        # The new page
        page_fopt($page_name, "create", "allows_incoming_links");
        if (! $linking_is_one_way) {
            page_fopt($page_name, "create", "has_linking");
        }

        # The pre-existing page
        if (! $linking_is_one_way) {
            page_fopt($relate_to_page, "create", "allows_incoming_links");
        }
        page_fopt($relate_to_page, "create", "has_linking");


        # Add search boxes to the top of the pages
        if ($add_search_box eq "both") {
            page_fopt($page_name, "create", "show_search_box");
            page_fopt($relate_to_page, "create", "show_search_box");
        }
        elsif ($add_search_box eq "preexisting") {
            page_fopt($relate_to_page, "create", "show_search_box");
        }
        
        my $related_page_filename = get_filename_for_revision($relate_to_page, "HEAD");
        my $related_page_data = Potoss::File::read_file($related_page_filename);

        my $should_add_link_to_top_of_related_page = 1;

        # If the related page was an alias, then you can't add content to it.
        if ( _is_page_alias_for($relate_to_page) ) {
            $should_add_link_to_top_of_related_page = 0;
        }

        # If the related page already has the new page in it as a link,
        # then don't add another link.
        if ( $related_page_data =~ /\[$page_name\]/ ) {
            $should_add_link_to_top_of_related_page = 0;
        }

        if ($should_add_link_to_top_of_related_page) {
            _write_new_page_revision($relate_to_page, "link to [$page_name]\n\n" . $related_page_data);
        }

        _calculate_linkable_pages_cache();

    }
    else {
        _write_new_page_revision($page_name, '');
    }

    do_redirect("./?$page_name");

}

sub _check_page_name_is_ok {
    my $page_name = shift;

    { # Length issues... too short or long

        if ($page_name eq "" ) {
            return "You have to have a name for your page.  If you can't think of one, hit the 'suggest' button next to the name box.";
        }

        if (length($page_name) <= 4) {
            return "The page name should be at least five characters long";
        }

        if (length($page_name) > 50) {
            return "Seriously?  That page name, $page_name, is crazy long!  Try to keep it under 50 characters so you will be able to paste the URL into an email without it wrapping.";
        }

    }

    { # Characters which shouldn't be in the page name

        # This wording is important... that's why it's in a single variable.
        # elsewhere there is a check for "may not contain", which you can 
        # search for in this file.  It checks this because it auto-suggests
        # a better page name.
        my $may_not_contain = "The page name may not contain";

        if ($page_name =~ m{ } ) {
            return "$may_not_contain spaces.  Use underscores instead.";
        }

        if ($page_name =~ m{-} ) {
            return "$may_not_contain hyphens.  Use underscores instead.";
        }

        if ($page_name =~ m{[A-Z]} ) {
            return "$may_not_contain upper case characters";
        }

        if ($page_name !~ m{\A [a-z_0-9]+ \z}xms ) {
            return "$may_not_contain characters other than a-z, 0-9, and underscores.";
        }
    }

    if ($page_name =~ m{\A (mom_birthday_2007|meeting_notes_070305) \z}xms ) {
        return "Seriously?!?  You can't name your page the same as one of the examples.  Everyone's going to try that.";
    }

    if (_is_in_dictionary($page_name)) {
        return qq~The word "$page_name" is in the dictionary.<br>That's not quite random enough.  Someone could easily guess it.  Try adding an underscore or a number to the name.~;
    }

    return "ok";
    
}

sub _is_in_dictionary {
    my $word = shift;

    return 0 if ! $word; #an empty word is not in the dictionary.

    my $matching_word = "";

    my $wordsfile = "$conf{CNF_DATA_DIR}/words";

    open(my $fh, "<", $wordsfile)
        || die "Cannot read from file $wordsfile - $!";

    my $regex = qr{ \A $word \z }xmsi;

    WORD:
    for my $line (<$fh>) {
        chomp($line);
        if ($line =~ $regex) {
            $matching_word = $line;
            last WORD;
        }
    }

    close($fh)
        || die "could not close $wordsfile after reading";

    return $matching_word;
}

sub normalize_page_name {
    my $name = shift;

    $name =~ tr/A-Z/a-z/;
    $name =~ tr/ /_/;
    $name =~ tr/-/_/;

    $name =~ s{[^a-z_0-9]}{}xmsg;

    return $name;
}

sub PH_show_page {
    my $page = $cgi->param("nm_page");
    my $rev = $cgi->param("nm_rev");
    show_page($page, $rev);
}

sub PH_plain {
    my $page = $cgi->param("nm_page");
    my $rev = $cgi->param("nm_rev") || "HEAD";

    my $filename = get_filename_for_revision($page, $rev);
    if ($ENV{SERVER_SOFTWARE} =~ m{HTTP::Server::Simple}) {
        print "HTTP/1.0 200 OK\r\n";
    }
    print $cgi->header(-type => 'text/plain', -expires => '-1d');

    if (! -e $filename){
        print "Error: the file does not exist";
    }
    else {
        print Potoss::File::read_file($filename);
    }
}

sub _encode_entities {
    my $data = shift;
    require HTML::Entities;
    return HTML::Entities::encode($data);
}

sub _wrap_text {
    my $text = shift;

    # gemhack 5 - This is a patched version [tag:patched:gem]
    require Text::Wrap;
    no warnings;
    $Text::Wrap::columns = 80;
    use warnings;
    return Text::Wrap::wrap('', '', $text);
}

#-----------------------------------------------------------------------------
# sect: links out
#-----------------------------------------------------------------------------

sub PH_page_links {
    my $page_name = $cgi->param('nm_page');
    my $max_depth = $cgi->param('nm_max_depth') || 10;
    my $search_query = $cgi->param('nm_search_query') || '';
    my $sort_by = $cgi->param('nm_sort_by') || 'order';
    my $prune_list = $cgi->param('nm_prune_list') || '';
    my $back_to_page = $cgi->param('nm_back_to_page') || '';
    my $mode = $cgi->param('nm_mode') || 'html';

        #throw($prune_list);

    if (! _is_in_set($mode, qw(html rss tgz)) ) {
        throw("mode must be html, rss, or tgz");
    }

    #untaint the search query
    $search_query .= '';

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    my @prune_list_array = split(/-/, $prune_list);



    my @links = eval { page_get_links_out_recursive($page_name, [], {max_depth => $max_depth, mode => 'cached', prune_list => \@prune_list_array}) };

    throw($@) if $@;

    my $num_pages_match_search = 0;
    my $rows = "";

    @links = sort {$a->{$sort_by} <=> $b->{$sort_by}} @links;

    my %num_circular_seen = ();

    my @after_search_pages = ();

    PAGE:
    for my $page (@links) {

        # Don't show circular linked page names if you're looking
        # at a "recent changes" style listing.  They only make sense
        # to show in the hierarchical listing.

        if ($sort_by eq 'modified' && $page->{is_circular}) {
            next PAGE;
        }

        my $warning = '';

        if ($page->{is_circular}) {
            if ($num_circular_seen{$page->{page_name}}) {
                $num_circular_seen{$page->{page_name}}++;
            }
            else {
                $num_circular_seen{$page->{page_name}} = 1;
            }
        }

        my $number_in_parens = $num_circular_seen{$page->{page_name}} + 1;

        $warning .= "($number_in_parens)" if $page->{is_circular};

        $warning = ($warning)
            ? qq~ <span style="color:red;">$warning</span>~
            : '';

        if ($search_query) {
            my $filename = get_filename_for_revision($page->{page_name}, "HEAD");

            if (! _page_exists($page->{page_name})) {
                page_does_not_exist($page->{page_name});
                return;
            }
            
            my $page_data = Potoss::File::read_file($filename);

            # make it case-insensitive
            my $lc_search_query = lc($search_query);
            $page_data = lc($page_data);

            # either the page name or the page contents can match
            if ( $page_data !~ m{$lc_search_query}
                    && $page->{page_name} !~ m{$lc_search_query} ) {
                next PAGE;
            }

            $num_pages_match_search++;
        }

        push @after_search_pages, $page;

        my @colors = qw(eee ddd ccc bbb aaa 999);
        my $indenting = '';

        DEEPNESS:
        for my $deepness (0..$page->{depth}) {
            next DEEPNESS if $deepness == 0;
            my $color = ($deepness <= 5)
                ? $colors[$deepness]
                : $colors[5];

            $indenting .= qq~<span style="background-color:#$color">&nbsp;&nbsp;&nbsp;</span>~;
        }

        my $prune = $prune_list . "-" . $page->{page_name};

        my $diffs_html = _page_latest_revisions_diffs_html($page->{page_name});

        $rows .= qq~
            <tr>
                <td style="padding:4px;">$indenting <a href="./?$page->{page_name}">$page->{page_name}$warning</a></td>
                <td style="padding:4px;">$page->{modified}</td>
                <td style="padding:4px;"><a href="./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=$prune&nm_sort_by=$sort_by">prune</a></td>
                <td style="padding:4px;">$diffs_html</td>
            </tr>
        ~;
    }

    my $maybe_search_results = ($search_query)
        ? "<h3>$num_pages_match_search pages found for search</h3>"
        : '';

    my @headings = (
        {title => "page", sort_by => "order", is_sortable => 1},
        {title => "days old", sort_by => "modified", is_sortable => 1},
        {title => "actions", is_sortable => 0},
        {title => "revisions", is_sortable => 0},
    );

    my $heading_str = '';
    for my $heading (@headings) {

        if ($heading->{is_sortable}) {
            my $style = ($heading->{sort_by} eq $sort_by)
                ? qq~style="background-color:#fee;padding:2px;"~
                : '';

            my $url = qq~./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=$prune_list&nm_sort_by=~;
            $heading_str .= qq~<th><a href="$url$heading->{sort_by}"$style>$heading->{title}</a></th>~;
        }
        else {
            $heading_str .= qq~<th>$heading->{title}</th>~;
        }
    }

    my $results_table = qq~
        <table>
            <tr>$heading_str</tr>
            $rows
        </table>
    ~;

    $results_table = ($search_query && $num_pages_match_search == 0)
        ? qq~<span style="color:red;">No matching results</span>~
        : $results_table;

    my $rss_feed_icon = qq~<a href="./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=$prune_list&nm_sort_by=$sort_by&nm_mode=rss&nm_need_rss_choice=1" style="margin-right:20px;">
        rss feed <img src="./static/rss.jpg" height="12" width="12" border="0"/>
    </a>~;

    my $tgz_link = qq~<a href="./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=$prune_list&nm_sort_by=$sort_by&nm_mode=tgz">
        create a backup tarball
    </a>~;

    my $unprune_all_link = '';
    if (@prune_list_array) {
        $unprune_all_link = qq~<a href="./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=&nm_sort_by=$sort_by">unprune all</a>~;
    }

    my $heading = '';
    if ($back_to_page) {
        $heading = qq~<div style="margin-top:20px; margin-bottom:20px;">Back to <a href="./?$page_name">$back_to_page</a></div>~;
    }
    else {
        $heading = qq~<h4>Links for: <a href="./?$page_name">$page_name</a></h4>~;
    }

    my $body = qq~
        <div id="myel_infbx_div" style="position:absolute; left:-1000px; top:0px; width:800px; background-color:#ddd; padding:6px;">&nbsp;</div>
        <script type="text/javascript">

            function infbxjs_HideInfoDiv () {
              ps = document.getElementById('myel_infbx_div');
              ps.style.left = "-1000px";
            }

            function infbxjs_ShowInfoDiv (obj, left_or_right_placement, info_text) {
              xleft = infbxjs_findPosX(obj);
              ytop = infbxjs_findPosY(obj);
              ps = document.getElementById('myel_infbx_div');
              ps.innerHTML = info_text;

              if (left_or_right_placement == "right"){
                ps.style.left = (xleft + 30) + "px";
                ps.style.top = ytop + "px";
              }
              else if (left_or_right_placement == "left") {
                ps.style.left = ((xleft - 15) - parseInt(ps.style.width)) + "px";
                ps.style.top = ytop + "px";
              }
            }

            function infbxjs_findPosX (obj) {
              var curleft = 0;
              if (obj.offsetParent) {
                while (obj.offsetParent) {
                  curleft += obj.offsetLeft
                  obj = obj.offsetParent;
                }
              }
              else if (obj.x) {
                curleft += obj.x;
              }
              return curleft;
            }

            function infbxjs_findPosY (obj) {
              var curtop = 0;
              if (obj.offsetParent) {
                while (obj.offsetParent) {
                  curtop += obj.offsetTop
                  obj = obj.offsetParent;
                }
              }
              else if (obj.y) {
                curtop += obj.y;
              }
              return curtop;
            }
        </script>
            
        $heading

        $maybe_search_results

        <form name="f" id="fr_search_links" method="post" action="./?" style="margin-bottom:20px;">
            <input type="hidden" name="PH_page_links" value="1">
            <input type="hidden" name="nm_page" value="$page_name">
            <input type="hidden" name="nm_prune_list" value="$prune_list">
            <input type="hidden" name="nm_sort_by" value="$sort_by">
            search pages for: <input type="text" id="myel_search_query" name="nm_search_query" value="$search_query" style="width:200px;margin-right:20px;">
            max_depth: <input type="text" name="nm_max_depth" value="$max_depth" style="width:30px;margin-right:20px;">
            <input type="submit" name="nm_submit" value="search" class="form">
            $unprune_all_link
        </form>

        <div style="margin-top:10px; margin-bottom:18px;">
            <span style="margin-right:10px;">For the pages listed:</span> $rss_feed_icon $tgz_link
        </div>
        
        $results_table
    ~;

    if ($mode eq 'html') {
        hprint($body, { page_name => $page_name, sub_page_name => "links" });
    }
    elsif ($mode eq 'rss' or $mode eq 'tgz') {
        #the names of the pages with no circular references
        my $pages_str =
            join('-',
                map({$_->{page_name}}
                    grep({$_->{is_circular} == 0}
                        @after_search_pages
                    )
                )
            );

        if ($mode eq 'rss') {
            if ( $cgi->param("nm_need_rss_choice") ) {
                my $url_base = qq~./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=$prune_list&nm_sort_by=$sort_by&nm_mode=rss~;
                hprint( _rss_choose_options($url_base), { page_name => $page_name, sub_page_name => "choose rss" } );
            }
            else {
                PH_rss($pages_str);
            }
        }

        if ($mode eq 'tgz') {
            PH_pages_tgz($pages_str);
        }
        
    }
}

sub _regex_all_possible_links {
    my $orig_word = shift;
    my $label = shift;
    my $these_are_links = shift;

    if (! $these_are_links->{$orig_word}) {
        $these_are_links->{$orig_word} = {order => scalar(keys %{$these_are_links})};
    }
}

sub is_a_valid_link {
    my $page_name = shift;

    my $resolved_alias = _is_page_alias_for($page_name);
    my $resolved_page_name = $resolved_alias || $page_name;

    (page_fopt($resolved_page_name, 'exists', 'allows_incoming_links'))
        ? return 1
        : return 0;
}

sub page_read_text_and_calculate_only_valid_links {
    my $page_name = shift;
    my @possible_links = page_read_text_and_calculate_all_possible_links($page_name);
    return grep({is_a_valid_link($_)} @possible_links);
}

sub page_read_text_and_calculate_all_possible_links {
    # Based on the page's text formatting, get all the links it might
    # possibly have.  Do not judge the validity of the links.  That is
    # done elsewhere.

    my $page_name = shift;
    my $resolved_alias = _is_page_alias_for($page_name);
    my $resolved_page_name = $resolved_alias || $page_name;

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    my $data = '';
    my $filename = get_filename_for_revision($resolved_page_name, "HEAD");

    if (! -e $filename) {
        page_does_not_exist($page_name);
        return;
    }
    
    my $page_data = Potoss::File::read_file($filename);

    my %all_possible_links = ();

    $page_data =~ s{\[([a-z_0-9]{5,}):?([^\]]*)\]}{_regex_all_possible_links($1, $2, \%all_possible_links)}ges;

    return sort {$all_possible_links{$a}->{order} <=> $all_possible_links{$b}->{order}} keys %all_possible_links;

}

sub _regex_process_words_for_links {
    my $orig_word = shift;
    my $label = shift || $orig_word;
    my $linkable_pages = shift;
    my $alias_pages = shift;
    my $these_are_not_links = shift;
    my $these_are_links = shift;
    my $no_opts = shift;

    if (exists $these_are_not_links->{$orig_word}) {
        return $orig_word;
    }

    if ( exists $these_are_links->{$orig_word}
        or grep ({ /^$orig_word$/ } @{$linkable_pages} ) ) {
            $these_are_links->{$orig_word} = 1;

            if ($no_opts) {
                return qq~<a href="./?PH_show_page&nm_page=$orig_word&nm_no_opts=1">$label</a>~;
            }
            else {
                return qq~<a href="./?$orig_word">$label</a>~;
            }
    }

    # If the word matches one of the page aliases, check if the target
    # page allows linking.  If so, return a link to the alias, otherwise
    # return the original word with no link.
    elsif (grep ({ /^$orig_word$/ } @{$alias_pages} )) {
        my $target_page = _is_page_alias_for($orig_word);
        if ( exists $these_are_links->{$target_page}
            or grep ({ /^$target_page$/ } @{$linkable_pages}) ) {
                $these_are_links->{$orig_word} = 1;

            if ($no_opts) {
                return qq~<a href="./?PH_show_page&nm_page=$orig_word&nm_no_opts=1">$label</a>~;
            }
            else {
                return qq~<a href="./?$orig_word">$label</a>~;
            }

        }
        else {
            return $orig_word;
        }
    }
    else {
        $these_are_not_links->{$orig_word} = 1;
        return $orig_word;
    }
}

# gemhack 4 - should consolidate the follow four subroutines into one.
sub _links_out_cache_file_create_or_update {
    my $page_name = shift;
    my $resolved_alias = _is_page_alias_for($page_name);
    my $resolved_page_name = $resolved_alias || $page_name;

    my @possible_links_out = page_read_text_and_calculate_all_possible_links($resolved_page_name);
    my $filename = "$conf{CNF_TEXTS_DIR}/$resolved_page_name";
    Potoss::File::write_file($filename . "_CACHE_possible_links_out", join("\n", @possible_links_out));
    return 1;
}

sub _links_out_cache_file_exists {
    my $page_name = shift;
    my $resolved_alias = _is_page_alias_for($page_name);
    my $resolved_page_name = $resolved_alias || $page_name;

    my $filename = "$conf{CNF_TEXTS_DIR}/$resolved_page_name";
    return -e $filename . "_CACHE_possible_links_out";
}

sub _links_out_cache_file_get {
    my $page_name = shift;
    my $resolved_alias = _is_page_alias_for($page_name);
    my $resolved_page_name = $resolved_alias || $page_name;

    my $filename = "$conf{CNF_TEXTS_DIR}/$resolved_page_name";
    return split("\n", Potoss::File::read_file($filename . "_CACHE_possible_links_out"));
}

sub _links_out_cache_file_remove {
    my $page_name = shift;
    my $resolved_alias = _is_page_alias_for($page_name);
    my $resolved_page_name = $resolved_alias || $page_name;

    my $filename = "$conf{CNF_TEXTS_DIR}/$resolved_page_name";
    return unlink($filename . "_CACHE_possible_links_out");
}

sub page_get_links_out_recursive {
    my $page_name = shift;
    my $found_pages = shift || [];
    my $arg_ref = shift;

    die "max_depth must be integer" if ! $arg_ref->{max_depth} || $arg_ref->{max_depth} !~ /^\d+$/;
    die "must be real or cached" if ! _is_in_set($arg_ref->{mode}, qw(real cached));

    my @prune_list = ($arg_ref->{prune_list})
        ? @{$arg_ref->{prune_list}}
        : ();

    if (grep({$_ eq $page_name} @prune_list)) {
        return;
    }

    my $resolved_alias = _is_page_alias_for($page_name);
    my $resolved_page_name = $resolved_alias || $page_name;

    if (! $arg_ref->{depth}){ 
        die qq~page "$resolved_page_name" does not have linking enabled~
            if ! page_fopt($resolved_page_name, 'exists', 'has_linking');

        $arg_ref->{initial_page_name} = $page_name;
        $arg_ref->{depth} = 0;
        $arg_ref->{parent} = '';
        $arg_ref->{is_circular} = 0;
        $arg_ref->{used_preexisting_cache} = 0;

        # gemhack 4 - this calculation should happen only once after alias
        # creation.  For now we don't have a central alias creation (or
        # deletion) subroutine, so just put it in here as a catch all.
        _calculate_alias_pages_cache();
    }

    my $filename = get_filename_for_revision($page_name, "HEAD");
    my $modified = -M $filename;

    my $page_count = 1;
    for my $page (@$found_pages) {
        if ($page->{page_name} eq $page_name) {
            $page_count++;
        }
    }

    # If you're not the base page...
    if ( $arg_ref->{depth} > 0 ) {
        push @$found_pages, {
            page_name => $page_name,
            page_count => $page_count,
            is_circular => $arg_ref->{is_circular},
            used_preexisting_cache => $arg_ref->{used_preexisting_cache},
            parent    => $arg_ref->{parent},
            depth    => $arg_ref->{depth},
            order     => scalar( @$found_pages ),
            modified     => $modified,
        };
    }

    return if $arg_ref->{is_circular};

    my $should_use_cache_file = 0;
    my $used_preexisting_cache = 0;

    if ( $arg_ref->{mode} eq 'cached' ) {
        $should_use_cache_file = 1;

        if (_links_out_cache_file_exists($page_name)) {
            $used_preexisting_cache = 1;
        }
        else {
            _links_out_cache_file_create_or_update($page_name);
        }

    }

    my @links = ();

    if ($should_use_cache_file) {
        my @all_possible_links = _links_out_cache_file_get($page_name);
        @links = grep({is_a_valid_link($_)} @all_possible_links);
    }
    else {
        @links = page_read_text_and_calculate_only_valid_links($page_name);
    }

    if ($arg_ref->{depth} < $arg_ref->{max_depth}) {
        my @deeper_links = ();

        LINK:
        for my $link_page_name (@links) {
            my %arg_ref_copy = %{$arg_ref};

            for my $page ( @$found_pages ) {
                if ($page->{page_name} eq $link_page_name) {
                    $arg_ref_copy{is_circular} = 1;
                }
            }
            $arg_ref_copy{parent} = $page_name;
            $arg_ref_copy{depth} = $arg_ref->{depth} + 1;
            $arg_ref_copy{used_preexisting_cache} = $used_preexisting_cache;
            push @deeper_links, page_get_links_out_recursive($link_page_name, $found_pages, \%arg_ref_copy);
        }
        push @links, @deeper_links;
    }

    # If you're at the top level, then you've already processed all the
    # other levels, so return the results.
    if ( $arg_ref->{depth} == 0 ) {
        return @$found_pages;
    }
}

sub _get_linkable_pages {
    return split("\n", Potoss::File::read_file("$conf{CNF_CACHES_DIR}/linkable_pages"));
}

sub show_page {
    my $page_name = shift;
    my $revision = shift || "HEAD";
    my $no_opts = $cgi->param('nm_no_opts') || 0;

    my $resolved_alias = _is_page_alias_for($page_name);

    my $resolved_page_name = $resolved_alias || $page_name;

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    my $data = '';

    my $filename = get_filename_for_revision($resolved_page_name, $revision);

    my $body = '';
    my $no_opts_uri = ($no_opts) ? "&nm_no_opts=1" : '';

    my $revision_alert = '';
    if ($revision ne "HEAD"){
        # Even though the person didn't request HEAD, the revision number
        # might be HEAD, so don't show an alert if that is the case.
        if (get_page_HEAD_revision_number($page_name, 'cached') != $revision) {
            $revision_alert = qq~
                <div>
                    <span style="color:red;">You are not looking at the latest revision.  You are looking at revision $revision.</span>
                    <a href="./?PH_show_page&nm_page=$page_name$no_opts_uri">Go to the latest revision</a>
                </div>
            ~;
        }
    }

    if (! _page_exists($page_name)) {
        page_does_not_exist($page_name);
        return;
    }

    my $page_creation_message = '';
    if (get_page_HEAD_revision_number($resolved_page_name, 'cached') == 0) {
        $page_creation_message = qq~
            <div style="background-color:#fee; padding:6px;">$conf{CNF_NEW_PAGE_MESSAGE}</div>
        ~;
    }

    my $empty_page_text = ($conf{CNF_DEFAULT_EMPTY_PAGE_MESSAGE})
        ? $conf{CNF_DEFAULT_EMPTY_PAGE_MESSAGE}
        : qq~Nothing is in the page yet.  Click the "edit this page" link to add some text.~;
    
    $data = Potoss::File::read_file($filename) || $empty_page_text;

    my %opts = (
        remove_border => 1,
        parser => 'normal',
    );

    my $encoded_data = "";
    my $add_sortable_table_js = 0;

    # Unless an option has been set to *not* wrap the text, wrap it.
    if (page_fopt($resolved_page_name, 'exists', 'use_creole')) {
        require Text::WikiCreole;
        $data =~ s{\r\n}{\n}g;
        $encoded_data = Text::WikiCreole::creole_parse($data);
        $opts{parser} = 'creole';
        $add_sortable_table_js = 1 if $encoded_data =~ /<table>/;
        $encoded_data =~ s/<table>/<table class="sortable">/g;
    }
    # Unless an option has been set to *not* wrap the text, wrap it.
    elsif (! page_fopt($resolved_page_name, 'exists', "has_no_text_wrap")) {
        # gemhack 5 - The Text::Wrap module was patched by Gordon to remove
        # the unexpanding of tabs because it was buggy and we don't use tabs
        # in our textareas. [tag:patched:gem]
        
        $data = join('', _wrap_text($data));
        
        # do not remove the border if it's wrapped, since the text will fit
        # inside of the border with no problems.
        $opts{remove_border} = 0;
    }

    if ($opts{parser} eq 'normal') {
        $encoded_data = _encode_entities($data);
        $encoded_data =~ s/ /&nbsp;/g;
        $encoded_data =~ s/\n/<br>/g;
    }

    if ( page_fopt($resolved_page_name, 'exists', 'has_linking') ) {

        # gemhack 4 - this calculation should happen only once after alias
        # creation.  For now we don't have a central alias creation (or
        # deletion) subroutine, so just put it in here as a catch all.
        _calculate_alias_pages_cache();

        my @alias_pages = _get_alias_pages();
        my @linkable_pages = _get_linkable_pages();
        my %these_are_not_links = ();
        my %these_are_links = ();
        $encoded_data =~ s{\[([a-z_0-9]{5,}):?([^\]]*)\]}{_regex_process_words_for_links($1, $2, \@linkable_pages, \@alias_pages, \%these_are_not_links, \%these_are_links, $no_opts)}ges;
    }

    #gemhack 4 - replace potosstgz with a link to the code
    $encoded_data =~ s{potosstgz}{<a href="/potoss.tgz">potoss.tgz</a>}g;

    my $edit = '';
    my $advanced = '';

    my $no_opts_str = ($no_opts) ? "&nm_no_opts=1" : '';
    my $edit_url = "./?PH_edit&nm_page=$page_name&nm_rev=$revision$no_opts_str";

    #If you're not trying to do anything fancy, give a nice URL.
    if ($should_use_colons && $no_opts_str eq '' && $revision eq 'HEAD') {
        $edit_url = "./?$page_name:edit";
    }

    if (! $resolved_alias) {
        $edit = qq~<a id="myel_edit_link" href="$edit_url" style="margin-right:40px;">edit this page</a>~;
        if ($should_use_colons) {
            $advanced = qq~<a href="./?$page_name:options">advanced options</a>~;
        }
        else {
            $advanced = qq~<a href="./?PH_page_opts&nm_page=$page_name">advanced options</a>~;
        }
    }
    else {
        $edit = qq~<span style="color:red;margin-right:20px;">this page is read only</span>~;
    }

    my $rss_url = ($should_use_colons)
        ? "./?$page_name:rss"
        : "./?PH_choose_rss&nm_pages=$page_name";

    my $rss_feed_icon = qq~<a href="$rss_url" style="float:right;">
        <img src="./static/rss.jpg" height="12" width="12" border="0"/>
    </a>~;

    # If you tell it to show no options, then don't show options.
    if ($no_opts) {
        $advanced = '';
        $rss_feed_icon = '';
    }

    my $show_encryption_buttons = page_fopt($page_name, 'exists', "show_encryption_buttons");
    my $remove_branding = page_fopt($page_name, 'exists', "remove_branding");
    my $remove_container_div = page_fopt($page_name, 'exists', "remove_container_div");

    my $create_new_link = ($should_use_colons)
        ? qq~<a href="./?$page_name:create" style="margin-right:40px;">create a new page</a>~
        : qq~<a href="./?PH_create_from_page&nm_page=$page_name" style="margin-right:40px;">create a new page</a>~;

    $create_new_link = '' if page_fopt($page_name, 'exists', "remove_create_new_link");

    my $blowfish_buttons = ($show_encryption_buttons) ? _blowfish_buttons("decrypt_only") : '';

    my $bar_color_hex = page_fopt($page_name, 'get', 'bar_color_hex') || 'eee';


    my $search_box = "";
    if ( page_fopt($page_name, 'exists', "show_search_box") ) {
        $search_box = qq~
            <form name="f" id="fr_search_links" method="post" action="./?" style="display:inline; margin-left:30px;">
                <input type="hidden" name="PH_page_links" value="1">
                <input type="hidden" name="nm_page" value="$page_name">
                <input type="hidden" name="nm_back_to_page" value="$page_name">
                <input type="hidden" name="nm_prune_list" value="">
                <input type="hidden" name="nm_sort_by" value="">
                <input type="text" id="myel_search_query" name="nm_search_query" value="" style="font-size:9px; width:100px; margin-right:2px;">
                <input type="submit" name="nm_submit" value="search" class="form" style="font-size:9px;">
            </form>
        ~;
    }

    $body = qq~
        $page_creation_message
        $rss_feed_icon
        <div style="margin-bottom:30px;background-color:#$bar_color_hex;">
            $edit
            $create_new_link
            $advanced
            $search_box
        </div>
        $revision_alert
        $blowfish_buttons
        <p id="myel_text" style="font-family:monospace;">$encoded_data</p>
        
    ~;

    hprint(
        $body,
        {   remove_border             => $opts{remove_border},
            remove_branding           => $remove_branding,
            remove_container_div      => $remove_container_div,
            page_name                 => $page_name,
            add_keys_js               => 1,
            add_blowfish_js           => $show_encryption_buttons,
            add_sortable_table_js     => $add_sortable_table_js,
            universal_edit_button_url => $edit_url,
            add_rss_to_head           => 1,
        }
    );

}

sub _get_alias_pages {
    return split("\n", Potoss::File::read_file("$conf{CNF_CACHES_DIR}/alias_pages"));
}

sub page_does_not_exist {
    my $page_name = shift;

    _slow_down_if_more_guesses_than(3); # [tag:security:gem] [tag:privacy:gem]

    my $body = qq~
        <p style="color:red;">This page doesn't exist.</p>
        <a href="./?PH_create_submit&nm_page=$page_name">create it as a new page</a>

        <p>or</p>

        <a href="./?PH_find">find a page I previously created</a>

    ~;

    hprint($body, { special_page_name => "does not exist" });

}

sub _clear_old_guess_ip_addresses {
    # Clear all guesses which are older than about a minute.  Return
    # a list of all the files which were cleared.
    # If the person was really trying to hack the site, they would be
    # trying more than one guess per minute.
    my @guesses_cleared = ();

    _compat_require_file_find();

    File::Find::find (sub {
        return if $_ !~ /^guess_/;
        return if -M $_ < 0.001;
        push @guesses_cleared, $_;
        unlink($_);
    }, $conf{CNF_CACHES_DIR});
    return @guesses_cleared;
}

sub _slow_down_if_more_guesses_than {
    # Subtly slow down the response if there are too many guesses from the
    # same IP address.  This is to try to avoid any kind of a brute force
    # attack from a single IP address.
    # [tag:security:gem] [tag:hacking:gem] [tag:hacker:gem]

    my $slow_after_how_many_guesses = shift;

    _clear_old_guess_ip_addresses();

    my $ip_address_of_guess = $ENV{REMOTE_ADDR};

    $ip_address_of_guess =~ s/\./_/g;

    my $guess_file = "$conf{CNF_CACHES_DIR}/guess_$ip_address_of_guess";

    my $num_guesses = (-e $guess_file)
        ? Potoss::File::read_file($guess_file)
        : 0;

    $num_guesses++;

    Potoss::File::write_file($guess_file, $num_guesses);

    # allow for three wrong guesses before starting to affect performance.
    # gemhack 4 - will "idling" the Perl script negatively affect the web
    # server's ability to serve more requests?
    my $was_slowed_down = 0;
    if ($num_guesses > $slow_after_how_many_guesses) {
        sleep 2 * ($num_guesses - $slow_after_how_many_guesses);
        $was_slowed_down = 1;
    }

    return $was_slowed_down;
}

#sub PH_create_readonly_alias {
#    my $page_name = $cgi->param("nm_page");
#    my $alias_name = $cgi->param("nm_alias");
#
#    my $error = _check_page_name_is_ok($page_name);
#    throw($error) if $error ne 'ok';
#
#    if ($error) {
#        $error = qq~
#            <div style="color:red;margin-bottom:10px;background-color:#fdd; padding:6px;">$error</div>
#        ~;
#    }
#    my $body = qq~
#        $error
#        <form id="fr_create" method="post" action="./?">
#            <input type="hidden" name="PH_create_readonly_alias" value="1">
#            <input type="hidden" name="nm_page" value="$page_name">
#            
#            Alias name (same constraints as a normal page name)
#            <div style="margin-bottom:10px;"><input id="myel_alias" type="text" name="nm_alias" value="$alias" class="form" style="width:300px"></div>
#            <div><input type="submit" name="nm_submit" value="create the page" class="form"></div>
#        </form>
#    ~;
#
#    hprint($body);
#}

sub _dt_rss {
    my $dt = shift;

    my $time_str = $dt->day_abbr . ", " .
        $dt->day . " " . $dt->month_abbr . " " . $dt->year . " " .
        $dt->hms . " GMT";

    return $time_str;

}

sub _diff_files {
    return _external_diff(@_);
}

sub _external_diff {
    my ($f1, $f2) = @_;
    my $diff = `diff $f1 $f2`;
    return $diff;
}

sub _internal_diff {
    # doesn't rely on unix diff.
    my ($f1, $f2) = @_;
    $f1 = Potoss::File::read_file($f1);
    $f2 = Potoss::File::read_file($f2);
    require Algorithm::Diff;
    my @diffs
        = Algorithm::Diff::diff( [split(/\n/, $f1)], [split(/\n/, $f2)] );

    my $text_diffs = '';
    for my $diff_a (@diffs) {
        for my $diff_b (@$diff_a) {
            $text_diffs .= join(' ', @$diff_b);
        }
        $text_diffs .= "\n";
    }
    return $text_diffs;
}

sub _page_latest_revisions_diffs_html {
    my $page_name = shift;

    $page_name = _resolve_alias($page_name) || $page_name;

    my $head_rev = get_page_HEAD_revision_number($page_name, 'cached');

    my $num_revs_to_show = 4;

    my $rev = $head_rev;

    my @diffs = ();

    while ($rev > 0) {
        my $start_file = get_filename_for_revision($page_name, $rev - 1);
        my $end_file = get_filename_for_revision($page_name, $rev);

        my $diff = _diff_files($start_file, $end_file);

        # do this step before encoding entries
        $diff =~ s{'}{\\'}g;

        my $diff_text = _encode_entities($diff);

        $diff_text =~ s{\r\n}{<br>}g;
        $diff_text =~ s{\n}{<br>}g;

        my $days_old = -M $end_file;
        $diff_text = "revised: $days_old days ago<br><br>$diff_text";
        
        push @diffs, {rev => $rev, text => $diff_text};

        $rev--;
        if ($rev <= $head_rev - $num_revs_to_show) {
            $rev = 0;
        }
    }

    my $diffs_html = '';
    for my $diff (@diffs) {
        my $cursor_order_matters = 'cursor:pointer; cursor:hand;';
        $diffs_html .= qq~
        <span style="background-color:#ccc; padding:2px; margin-right:1px; $cursor_order_matters" onmouseover="infbxjs_ShowInfoDiv(this, 'right', '$diff->{text}');" onmouseout="infbxjs_HideInfoDiv(this);" >$diff->{rev}</span>
        ~;
    }

    return $diffs_html;
    
}

sub PH_choose_rss {

    my $page_names = $cgi->param("nm_pages");

    # You can also pass it only one page, if that's your want.
    if (! $page_names) {
        $page_names = $cgi->param("nm_page");
    }

    my $url_base = "./?PH_rss&nm_double_check_names=1&nm_pages=$page_names";

    hprint( _rss_choose_options($url_base), { special_page_name => "choose RSS" } );
}

sub _rss_choose_options {
    my $url_base = shift;
    my $body = qq~
        <div style="margin-bottom:10px;"><em>Two different types of feeds are available:</em></div>
        <div style="margin-bottom:10px;">
            <a href="$url_base&nm_rss_mode=diffs_only"><img src="./static/rss.jpg" height="12" width="12" border="0"/> Differences Only</a>
        </div>
        <div>
            <a href="$url_base&nm_rss_mode=full"><img src="./static/rss.jpg" height="12" width="12" border="0"/> Differences and Full Text</a>
            <span style="margin-left:10px; color:#393;">... can function as a backup</span>
        </div>
    ~;

    return $body;
}

sub PH_rss {
    require DateTime;

    my $page_names = shift;

    # If not called from the PH_page_links subroutine.
    if (! $page_names) {
        $page_names = $cgi->param("nm_pages") || throw("Needs at least one page name.");
    }

    my $rss_mode = $cgi->param("nm_rss_mode") || 'diffs_only';
    my $double_check_page_names = $cgi->param("nm_double_check_names") || 0;

    my $MAX_NUM_REVISIONS = 20;

    my @pages = split(/-/, $page_names);

    # If you're looking at more than one page, show a prefix in
    # front of the revision number for the page.
    my $show_page_prefixes = (scalar(@pages) > 1) ? 1 : 0;

    if ($double_check_page_names) {
        for my $page_name (@pages) {
            my $error = _check_page_name_is_ok($page_name);
            throw($error) if $error ne 'ok';
        }
    }

    my $final_revision_time_str = '';

    my @all_page_revisions = ();

    for my $page_name (@pages) {
        my $finish_revision = get_page_HEAD_revision_number($page_name, 'cached');

        my $start_revision = $finish_revision - $MAX_NUM_REVISIONS;
        if ($start_revision < 0){
            $start_revision = 0;
        }

        REVISION:
        for my $rev ($start_revision..$finish_revision) {

            my $revision_ref = {};

            next REVISION if $rev < 1;

            my $start_file = get_filename_for_revision($page_name, $rev - 1);
            my $end_file = get_filename_for_revision($page_name, $rev);

            my $dt = DateTime->now();
            my $days_old = -M $end_file;
            $dt->subtract( seconds => $days_old * 3600 * 24 );
            my $this_revision_time_str = _dt_rss($dt);

            my $diff = _diff_files($start_file,$end_file);
            my $diff_text = _encode_entities($diff);

            my $page_prefix = ($show_page_prefixes)
                ? "$page_name - "
                : '';

            my $description_text = $diff_text;

            if ( $rss_mode eq 'full' ) {
                my $filename = get_filename_for_revision($page_name, $rev);
                if (! -e $filename){
                    throw("Error: the file for $page_name, $rev does not exist");
                }
                else {
                    my $plain_text = Potoss::File::read_file($filename);
                    $description_text .= "\n#### start of $page_name full plain text #####\n";
                    $description_text .= $plain_text;
                }
            }

            $description_text =~ s{\n}{<br>}g;

            $revision_ref->{days_old} = $days_old;
            $revision_ref->{page_name} = $page_name;
            $revision_ref->{revision_rss_time} = $this_revision_time_str;
            $revision_ref->{rss_item} = qq~
                 <item>
                  <title>${page_prefix}revision $rev</title>
                  
                  <link>http://$conf{CNF_SITE_BASE_URL}/?PH_show_page&amp;nm_page=$page_name&amp;nm_rev=$rev</link>
                  <pubDate>$this_revision_time_str</pubDate>
                  <guid>http://$conf{CNF_SITE_BASE_URL}/?PH_show_page&amp;nm_page=$page_name&amp;nm_rev=$rev</guid>
                  <description><![CDATA[$description_text]]></description>
                </item>
            ~;

            push @all_page_revisions, $revision_ref;

        }
    }

    @all_page_revisions = sort {$a->{days_old} <=> $b->{days_old}} @all_page_revisions;

    my $items = '';
    my $counter = 0;

    ITEM:
    for my $revision_ref (@all_page_revisions) {
        $counter++;
        last ITEM if $counter > $MAX_NUM_REVISIONS;
        $items .= $revision_ref->{rss_item};
        $final_revision_time_str = $revision_ref->{revision_rss_time};
    }

my $body = qq~<?xml version="1.0"?>
<rss version="2.0">
  <channel>
    <title>http://$conf{CNF_SITE_BASE_URL} changes</title>
    <link>http://$conf{CNF_SITE_BASE_URL}</link>
    <description>$conf{CNF_SITE_BASE_URL} changes</description>
    <language>en-us</language>
    <pubDate>$final_revision_time_str</pubDate>
    <lastBuildDate>$final_revision_time_str</lastBuildDate>
    <docs>http://www.rssboard.org/rss-specification</docs>
    <generator>$conf{CNF_SITE_BASE_URL} website</generator>
    <managingEditor>$conf{CNF_ADMIN_EMAIL}</managingEditor>
    <webMaster>$conf{CNF_ADMIN_EMAIL}</webMaster>
    <ttl>30</ttl>

    $items
    
  </channel>
</rss>~;

    if ($cgi->param("nm_mode") eq 'html') {
        hprint($body, { special_page_name => "RSS" });
    }
    else {
        if ($ENV{SERVER_SOFTWARE} =~ m{HTTP::Server::Simple}) {
            print "HTTP/1.0 200 OK\r\n";
        }
        print $cgi->header(-type => 'application/rss+xml', -expires => '-1d');
        filter_print($body);
    }

}

sub _blowfish_buttons {
    my $mode = shift;
    throw("mode must be both or decrypt_only") if
        ! _is_in_set($mode, qw(both decrypt_only) );

    my $encrypt = qq~
        <a href="javascript:do_blowfish('encrypt', document.getElementById('myel_blowfish_key').value)">encrypt</a> or 
    ~;

    $encrypt = '' if $mode eq 'decrypt_only';

    return qq~
    <div style="padding:10px;background-color:#eee;">
        $encrypt
        <a href="javascript:do_blowfish('decrypt', document.getElementById('myel_blowfish_key').value)">decrypt</a> using the key
        <input id="myel_blowfish_key" type="password" value="" />
    </div>
    ~;
}

sub PH_edit {
    my $page_name = $cgi->param("nm_page");
    my $revision = $cgi->param("nm_rev") || 'HEAD';
    my $no_opts = $cgi->param('nm_no_opts') || 0;

    my $textarea_rows = $cgi->param('nm_textarea_rows') || 22;
    my $textarea_cols = $cgi->param('nm_textarea_cols') || 80;

    for my $num ( $textarea_rows, $textarea_cols ) {
        if ( ! $num =~ /^\d+$/ ) {
            throw("either nm_textarea_rows or nm_textarea_cols is not a number");
        }
    }

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    if (_is_page_alias_for($page_name)){
        my $error = qq~You can't edit this page~;
        throw($error) if $error ne 'ok';
    }

    my $text = '';

    my $filename = get_filename_for_revision($page_name, $revision);
    
    if (-e $filename) {
        $text = Potoss::File::read_file($filename) || "";
    }

    my $head_revision_number = get_page_HEAD_revision_number($page_name, 'cached');
    my $revision_alert = '';

    my $no_opts_uri = ($no_opts) ? "&nm_no_opts=1" : '';

    if ($revision ne "HEAD"){
        # Even though the person didn't request HEAD, the revision number
        # might be HEAD, so don't show an alert if that is the case.
        if ($head_revision_number != $revision) {
            $revision_alert = qq~
                <div>
                    <span style="color:red;">You are not editing the latest revision.  You are looking at revision $revision.</span>
                    <a href="./?PH_edit&nm_page=$page_name&nm_rev=HEAD$no_opts_uri">Edit the latest revision</a>
                </div>
            ~;
        }
    }

    my $first_edit_alert = '';

    if (! $text){
        $first_edit_alert = qq~
            <div style="background-color:#fee;padding:4px;">
                <p><em>This message only appears the first time you edit a page.</em></p>

                <p>Just so you know, $conf{CNF_ADMIN_FIRST_NAME} will occasionally need to search through the pages
                (<strong>and potentially read them</strong>) to help people find their lost pages.</p>

                <p>By continuing <strong>you are agreeing</strong> that it is
                not the end of the world if $conf{CNF_ADMIN_HE_OR_SHE} see the contents of this page.</p>

                <p>Also, it is possible that someone will guess your URL, in which case they
                may <strong>read your page</strong>.  In other words, <strong>don't put anything
                too sensitive up here</strong>.</p>
                </p>
            </div>
        ~;
    }

    # gemhack 1 - Don't let the hackers close the textarea tag.
    # If they could, then they would be able to display arbitrary html
    # afterwards, and could add malicious JavaScript, iframe content, etc.
    # [tag:security:gem] [tag:hacking:gem] [tag:hacker:gem]
    # gemhack 3 - Update... actually, this may not be necessary since we escape
    # < and > to &lt; and &gt;, but I'll leave it in until I've had a chance
    # to think through it more and be *sure* it's not needed.
    $text =~ s/textarea/text_area/gi;

    my $show_encryption_buttons = page_fopt($page_name, 'exists', "show_encryption_buttons");
    my $remove_branding = page_fopt($page_name, 'exists', "remove_branding");
    my $remove_container_div = page_fopt($page_name, 'exists', "remove_container_div");

    # [tag:privacy:gem] - The blowfish buttons contain a form field.  Do not put
    # them within the main form because we don't want to send the secret key
    # to the server along with the textarea.  That would be bad.  The secret
    # key should only ever be in the user's browser, and not available to the
    # server.  Ever.
    my $blowfish_buttons_do_not_put_in_form = ($show_encryption_buttons)
        ? _blowfish_buttons("both")
        : '';

    my $cancel_url = "./?PH_show_page&nm_page=$page_name&nm_rev=$revision$no_opts_uri";

    #If you're not trying to do anything fancy, give a nice URL.
    if ($should_use_colons && $no_opts_uri eq '' && ($revision eq 'HEAD' || $revision eq '') ) {
        $cancel_url = "./?$page_name";
    }

    my $message_about_type_of_text = (page_fopt($page_name, 'exists', "use_creole"))
        ? qq~<p style="color:#339" style="margin-top: 40px;">
            This page uses <em><strong>Creole</strong></em>, a standardized
            wiki markup.
            Click <a href="./static/creole_cheatsheet.jpg" target="_blank">here</a>
            for a cheat sheet.</p>~
        : qq~<p style="color:#339">Use just plain text.  There's no fanciness here.</p>~
        ;

    my $onclick_javascript_verify_encrypted = ($blowfish_buttons_do_not_put_in_form)
        ? qq~onclick="only_submit_if_textarea_encrypted();"~
        : qq~onclick="document.getElementById('fr_edit_page').submit();"~;

    my $recaptcha = (page_fopt($page_name, 'exists', "use_recaptcha"))
        ? _recaptcha_fields()
        : "";

    my $body = qq~
        $revision_alert
        $first_edit_alert

        $message_about_type_of_text

        $blowfish_buttons_do_not_put_in_form

        <form id="fr_edit_page" method="post" action="./?$page_name">
            <input type="hidden" name="PH_page_submit" value="1">
            <input type="hidden" name="nm_page" value="$page_name">
            <input type="hidden" name="nm_no_opts" value="$no_opts">
            <input type="hidden" name="nm_head_revision_number_at_edit_start" value="$head_revision_number">

            <textarea id="myel_text_area" name="nm_text" cols="$textarea_cols" rows="$textarea_rows" style="font-size:12px;">$text</textarea>

            <div>
                $recaptcha
                <input type="button" name="nm_submit" value="save" class="form" $onclick_javascript_verify_encrypted style="margin-right:10px;">
                <!--<input type="button" value="test" class="form" $onclick_javascript_verify_encrypted style="margin-right:10px;">-->
                <input type="button" value="cancel" class="form" onclick="document.location = '$cancel_url';">
            </div>
        </form>
    ~;

    hprint($body,
        {
            add_blowfish_js => $show_encryption_buttons,
            add_keys_js               => 1,
            remove_branding => $remove_branding,
            remove_container_div => $remove_container_div,
            add_rss_to_head => 1,
            page_name => $page_name,
            sub_page_name => 'edit',
        }
    );
}

sub _validate_recaptcha_or_throw {
    require Captcha::reCAPTCHA;
    my $c = Captcha::reCAPTCHA->new;

    my $challenge = $cgi->param("recaptcha_challenge_field");
    my $response = $cgi->param("recaptcha_response_field");

    # Verify submission
    my $result = $c->check_answer(
        $conf{"CNF_RECAPTCHA_PRIVATE_KEY"}, $ENV{'REMOTE_ADDR'},
        $challenge, $response
    );

    if ( ! $result->{is_valid} ) {
        # reCAPTCHA gave an error

        my $error = $result->{error};
        if ($error =~ /incorrect-captcha-sol/) {
            throw "The words you typed into the reCAPTCHA field weren't right.  Hit the back button and try again."
        }
        else {
            throw "reCAPTCHA gave an error: " . $error;
        }
    }

}

sub _recaptcha_fields {
    my $recaptcha = qq~
        <script type="text/javascript"
           src="http://api.recaptcha.net/challenge?k=$conf{CNF_RECAPTCHA_PUBLIC_KEY}">
        </script>

        <noscript>
           <iframe src="http://api.recaptcha.net/noscript?k=$conf{CNF_RECAPTCHA_PUBLIC_KEY}>"
               height="300" width="500" frameborder="0"></iframe><br>
           <textarea name="recaptcha_challenge_field" rows="3" cols="40">
           </textarea>
           <input type="hidden" name="recaptcha_response_field"
               value="manual_challenge">
        </noscript>
    ~;
    return $recaptcha;
}

sub _fopts_params {
    my $page_name = shift;
    my $message = "";

    my %fopts = get_fopts();
    for my $fopt_name (sort keys %fopts) {

        my $param = $cgi->param("nm_" . $fopt_name);
        if (defined $param){
            if ($fopts{$fopt_name}->{data_type} eq 'bool') {
                my $action = ($param eq 'yes') ? 'create' : 'remove';

                if ($fopt_name eq 'use_recaptcha') {
                    _validate_recaptcha_or_throw();
                }

                page_fopt($page_name, $action, $fopt_name);
                $message = $fopts{$fopt_name}->{"${param}_message"};

                if ($fopt_name eq 'allows_incoming_links') {
                    _calculate_linkable_pages_cache();
                }
            }
            elsif ($fopts{$fopt_name}->{data_type} eq 'color') {
                if ($param !~ m{[0-9a-fA-F]{3,6}}) {
                    throw("Must be a valid hexadecimal color without the prepended #");
                }
                else {
                    page_fopt($page_name, 'create', $fopt_name, $param);
                    $message = $fopts{$fopt_name}->{set_message};
                }
            }
            elsif ($fopts{$fopt_name}->{data_type} eq 'read_only_page_name_list') {

                my $pre_existing_page_aliases_list_string = page_fopt($page_name, 'get', $fopt_name);
                set_read_only_aliases_from_page_list($page_name, $param, $pre_existing_page_aliases_list_string);
                page_fopt($page_name, 'create', $fopt_name, $param);
                $message = $fopts{$fopt_name}->{set_message};
            }
        }
    }

    return $message;

}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
# Start Aliases
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

sub _page_is_an_alias {
    my $page_name = shift;

    if ( _resolve_alias($page_name) eq $page_name ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _resolve_alias {
    my $page_name = shift;

    my $resolved_alias = _is_page_alias_for($page_name);
    if ($resolved_alias){
        return $resolved_alias;
    }

    return $page_name;
}

sub _is_page_alias_for {
    my $page_name = shift;

    my $filename = "$conf{CNF_TEXTS_DIR}/$page_name";
    my $alias_file = $filename . "_ALIAS";

    if (-e $alias_file){
        my $target_page_name = Potoss::File::read_file($alias_file);
        chomp($target_page_name);
        return $target_page_name;
    }

    my $deactivated_alias_file = $filename . "_ALIAS_DEACTIVATED";

    if (-e $deactivated_alias_file){
        throw("this alias has been deactivated");
    }

    return 0;
}

sub _get_alias_filename_for_alias_page_name {
    my $page_name = shift;
    my $filename = "$conf{CNF_TEXTS_DIR}/$page_name";
    my $alias_file = $filename . "_ALIAS";
}

sub _create_alias {
    my $page_name = shift;
    my $alias_page_name = shift;

    my $alias_file = _get_alias_filename_for_alias_page_name($alias_page_name);
    Potoss::File::write_file($alias_file, $page_name);
}

sub _remove_alias {
    my $alias_page_name = shift;

    if (! _page_is_an_alias($alias_page_name) ) {
        throw("cannot remove the alias listed in page $alias_page_name because page $alias_page_name is not an alias.");
    }

    my $alias_file = _get_alias_filename_for_alias_page_name($alias_page_name);

    if (! -e $alias_file) {
        throw("Trying to remove an alias file, $alias_file, that does not exist.");
    }

    unlink($alias_file);
}

sub set_read_only_aliases_from_page_list {
    my $page_name = shift;
    my $new_page_aliases_list_string = shift || "";
    my $pre_existing_page_aliases_list_string = shift || "";

    if (! _page_exists($page_name) ) {
        throw("The page you're trying to set aliases for, $page_name, does not exist.");
    }

    # Check that the new list of page_names supplied by the form
    # is of the correct format, and will actually work.
    my @new_page_alias_list = split(/\s*,\s*/, $new_page_aliases_list_string);

    if ( scalar(@new_page_alias_list) > 5 ) {
        throw("Sorry, but you cannot create more than five read-only aliases to a page.");
    }

    for my $alias_page_name ( @new_page_alias_list ) {
        my $base_error = "The page name, $alias_page_name, in your read-only list";
        if ( _check_page_name_is_ok($alias_page_name) ne 'ok' ) {
            throw("$base_error does not match the page naming criteria.");
        }

        if ( _page_exists($alias_page_name) && ! _page_is_an_alias($alias_page_name) ) {
            throw("$base_error is already a real page, so it can't be made into a read-only list.");
        }

        if ( _page_is_an_alias($alias_page_name) && _resolve_alias($alias_page_name) ne $page_name ) {
            throw("$base_error is already a read-only alias for another page.");
        }
    }

    # If there is already a stored list of read-only alias pages,
    # remove any that are no longer in the newly provided list
    # before you add the new ones.
    my @preexisting_list = split(/\s*,\s*/, $pre_existing_page_aliases_list_string);
    if ( @preexisting_list ) {
        for my $pre_existing_page_alias (@preexisting_list) {
            if (! grep {$_ eq $pre_existing_page_alias} @new_page_alias_list ) {
                _remove_alias($pre_existing_page_alias);
            }
        }
    }

    # Now, create any new alias files.
    for my $alias_page_name ( @new_page_alias_list ) {
        _create_alias($page_name, $alias_page_name);
    }

}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
# End Aliases
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

sub _fopts_links {
    my $page_name = shift;
    my $url = shift;

    my %fopts = get_fopts();
    my %fopt_link_for = ();
    for my $fopt_name (sort keys %fopts) {

        my $level = $fopts{$fopt_name}->{level};
        my $url_base = qq~<a href="./?$url&nm_page=$page_name&nm_level=$level&nm_$fopt_name=~;
        if ($fopts{$fopt_name}->{data_type} eq 'bool') {
            if ( page_fopt($page_name, 'exists', $fopt_name) ){
                $fopt_link_for{$fopt_name} = $url_base . qq~no">~
                    . $fopts{$fopt_name}->{no_link} . "</a>";
            }
            else {
                $fopt_link_for{$fopt_name} = $url_base . qq~yes">~
                    . $fopts{$fopt_name}->{yes_link} . "</a>";
            }
        }
    }

    return %fopt_link_for;
}

sub PH_compact_page_opts {
    my $page_name = $cgi->param("nm_page");

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    if (_is_page_alias_for($page_name)){
        my $error = qq~You can't view this page's compact options~;
        throw($error) if $error ne 'ok';
    }

    my $message = _fopts_params($page_name);
    my %fopt_link_for = _fopts_links($page_name, 'PH_compact_page_opts');

    if ($message) {
        $message = qq~
            <p style="color:green;">$message</p>
        ~;
    }

    my $body = $message;

    $body .= qq~
        <p>$fopt_link_for{has_linking}</p>
        <p>$fopt_link_for{allows_incoming_links}</p>

        <p style="margin-top:20px;">$fopt_link_for{has_no_text_wrap}</p>
        <p style="margin-top:20px;">$fopt_link_for{use_creole}</p>
        ~;

#    for my $key (keys %fopt_link_for) {
#        $body .= "<p>$key : $fopt_link_for{$key}</p>";
#    }

    hprint($body, {stylesheet_only => 1, special_page_name => 'compact opts'});

}

sub PH_page_opts {
    my $page_name = $cgi->param("nm_page");
    my $level = $cgi->param("nm_level") || 'minimally';

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    if (_is_page_alias_for($page_name)){
        my $error = qq~You can't view this page's options~;
        throw($error) if $error ne 'ok';
    }

    my $message = _fopts_params($page_name);
    my %fopt_link_for = _fopts_links($page_name, 'PH_page_opts');

    if ($message) {
        $message = qq~
            <p style="color:green;">$message</p>
        ~;
    }

    my $sub_nav = '';
    for my $level_text (qw(minimally more very)){
        my $style = qq~style="border:1px; border-color:#ccc; border-style:solid; margin-right:14px; padding:4px; ~;
        $style .= ($level eq $level_text) ? qq~background-color:#eee;"~ : qq~background-color:#ccc;"~;
        $sub_nav .= qq~<a href="./?PH_page_opts&nm_page=$page_name&nm_level=$level_text" $style>$level_text advanced</a>~;
    }

    $sub_nav = qq~
        <div>
            $sub_nav
        </div>
    ~;

    my %text_for_level = ();

    $text_for_level{minimally} = qq~
            <a href="./?PH_page_revisions&nm_page=$page_name">show the page's revision history</a>
            <p style="height:100px;">&nbsp;</p>
        </div>
    ~;

    # [tag:hacker:gem] You should not be able to turn on, or turn off
    # recaptcha without actually filling in a recaptcha by hand, since otherwise
    # hackers would just turn off the recaptcha automatically.

    # [tag:feature:gem] however, in the future it would be nice to give the site
    # owner a little bit of leverage to turn reCAPTCHA on easily if they know a
    # secret key.  That way they wouldn't have to fight with spammers by hand.

    # [tag:smell:gem] could be cleaned up just a bit given the time...
    my $recaptcha_action = (page_fopt($page_name, 'exists', "use_recaptcha"))
        ? 'disable'
        : 'enable';

    my $recaptcha_bool = (page_fopt($page_name, 'exists', "use_recaptcha"))
        ? 'no'
        : 'yes';

    my $recaptcha_fields = _recaptcha_fields();

    $text_for_level{more} = qq~
            <div style="margin-bottom:30px;"><strong>RSS feed</strong>
                <p style="margin-left:20px;margin-bottom:20px;"><a href="./?PH_choose_rss&nm_pages=$page_name">RSS feed of this page</a></p>
            </div>
            <div style="margin-bottom:30px;"><strong>Linking</strong>
                <p style="margin-left:20px;">$fopt_link_for{"has_linking"}</p>
                <p style="margin-left:20px;">$fopt_link_for{"allows_incoming_links"}</p>
            </div>

            <div style="margin-bottom:40px;"><strong>Text Wrapping</strong>
                <p style="margin-left:20px;">$fopt_link_for{"has_no_text_wrap"}</p>
            </div>

            <div style="margin-bottom:30px;">
                <strong>Search Box</strong>
                <p style="margin-left:20px;">Add a search box to the top of the page.  If you have links to other pages, you will be able to search the other pages using the search box.</p>
                <p style="margin-left:20px;">$fopt_link_for{"show_search_box"}</p>
            </div>

            <div style="margin-bottom:30px;">
                <strong>Hide from find results</strong>
                <p style="margin-left:20px;">Hide the page from the 'find a page' search results.</p>
                <p style="margin-left:20px;">You might want to do this if you're concerned about people accidentally finding this page when they're looking for a page they lost, and you're sure you won't forget the page's URL.</p>
                <p style="margin-left:20px;">$fopt_link_for{"hide_from_find"}</p>
            </div>

            <div style="margin-bottom:30px;"><strong>Creole</strong>
                <p style="margin-left:20px;">$fopt_link_for{"use_creole"}</p>
            </div>

            <div style="margin-bottom:30px;"><strong>reCAPTCHA</strong>
                <p>
                    To $recaptcha_action reCAPTCHA on this page, you need to fill in the following reCAPTCHA:
                </p>
                <form id="fr_use_recaptcha" method="post" action="./?">
                    <input type="hidden" name="PH_page_opts" value="1">
                    <input type="hidden" name="nm_page" value="$page_name">
                    <input type="hidden" name="nm_level" value="more">
                    <input type="hidden" name="nm_use_recaptcha" value="$recaptcha_bool">
                    $recaptcha_fields
                    <input type="submit" name="nm_submit" value="$recaptcha_action reCAPTCHA" class="form">
                </form>
            </div>

            <div style="margin-bottom:30px;"><strong>Notes about doing things faster</strong>
                <p style="margin-left:20px;">You can double click on the text to edit it.</p>
            </div>

        </div>
    ~;

    my $plain_text_url = "http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name";
    my $bar_color_hex = page_fopt($page_name, 'get', 'bar_color_hex') || 'eee';
    my $read_only_aliases = page_fopt($page_name, 'get', 'read_only_aliases') || '';

    $text_for_level{very} = qq~
            <div style="margin-bottom:30px;"><strong>Keyboard Shortcuts</strong>
                <p style="margin-left:20px;">the 'w' key brings up some page options when viewing the text.</p>
            </div>

            <div style="margin-bottom:30px;"><strong>Multiple pages in a single RSS feed</strong>
                <p style="margin-left:20px;">Use a minus to delimit the pages.</p>
                <p style="margin-left:20px;">For example, for diffs only of <span style="color:#448;margin-left:10px;margin-right:10px;">mom_birthday_2007</span> and <span style="color:#448;margin-left:10px;margin-right:10px;">meeting_notes_070305</span> you would say:</p>
                <p style="margin-left:20px;">http://$conf{CNF_SITE_BASE_URL}/?PH_rss&nm_pages=mom_birthday_2007-meeting_notes_070305</p>
                <p style="margin-left:20px;">For example, for diffs and full text of <span style="color:#448;margin-left:10px;margin-right:10px;">mom_birthday_2007</span> and <span style="color:#448;margin-left:10px;margin-right:10px;">meeting_notes_070305</span> you would say:</p>
                <p style="margin-left:20px;">http://$conf{CNF_SITE_BASE_URL}/?PH_rss&nm_rss_mode=full&nm_pages=mom_birthday_2007-meeting_notes_070305</p>
            </div>
            
            <div style="margin-bottom:30px;"><strong>Plain text</strong> (not delivered in an html container) to facilitate easy page scraping:
                <p style="margin-left:20px;">the latest rev: <a href="http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name">http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name</a></p>
                <p style="margin-left:20px;">rev 2: <a href="http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name&nm_rev=2">http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name&nm_rev=2</a></p>
            </div>

            <div style="margin-bottom:30px;"><strong>Page Data</strong>
                <p style="margin-left:20px;">Page as a .tgz file (includes all revisions and options)</p>
                <p style="margin-left:20px;">Click <a href="./?PH_pages_tgz&nm_pages=$page_name">here</a> to create the tgz file.</p>
            </div>

            <div style="margin-bottom:30px;"><strong>Search Across Links</strong>
                <p style="margin-left:20px;"><a href="./?PH_page_links&nm_page=$page_name">Search Across Links</a></p>
            </div>

            <div style="margin-bottom:30px;"><strong>Read-only aliases</strong>
                <p style="margin-left:20px;">You can create read-only page aliases for this page</p>
                <div style="margin-left:20px;">
                    <form id="fr_read_only_aliases" method="post" action="./?">
                        <input type="hidden" name="PH_page_opts" value="1">
                        <input type="hidden" name="nm_page" value="$page_name">
                        <input type="hidden" name="nm_level" value="very">
                        read-only page aliases (comma seperated): <input type="text" name="nm_read_only_aliases" value="$read_only_aliases" style="width:200px;">
                        <input type="submit" name="nm_submit" value="set aliases" class="form">
                    </form>
                </div>
            </div>

            <div style="margin-bottom:30px;">
                <!--[tag:security:gem] [tag:privacy:gem]-->
                <strong>Encryption:</strong> Symmetric-key client-side text encryption and decryption using blowfish.
                <p style="margin-left:20px;">If you use this:</p>
                <ul style="margin-left:20px;">
                    <li>BAD: the site's administrator will not be able to recover your page based on its contents.</li>
                    <li>BAD: the revision control system will not be able to display differences in a way which makes sense to people.</li>
                    <li>GOOD: The page will be encrypted client-side, so the plain text is never visible to the site administrator.</li>
                </ul>
                <p style="margin-left:20px;">$fopt_link_for{"show_encryption_buttons"}</p>
            </div>

            <div style="margin-bottom:30px;"><strong>Embedding</strong>
                <p style="margin-left:20px;">You can remove the branding and the 'create new page' link to make the page cleaner when embedding in an iframe, for example.</p>
                <p style="margin-left:20px;">$fopt_link_for{"remove_branding"}</p>
                <p style="margin-left:20px;">$fopt_link_for{"remove_create_new_link"}</p>
                <p style="margin-left:20px;">$fopt_link_for{"remove_container_div"}</p>
                <div style="margin-left:20px;">
                    <form id="fr_bar_color_hex" method="post" action="./?">
                        <input type="hidden" name="PH_page_opts" value="1">
                        <input type="hidden" name="nm_page" value="$page_name">
                        <input type="hidden" name="nm_level" value="very">
                        bar color hex: #<input type="text" name="nm_bar_color_hex" value="$bar_color_hex" style="width:30px;">
                        <input type="submit" name="nm_submit" value="set color" class="form">
                    </form>
                </div>
                <p style="margin-left:20px;">To show without the "advanced options", the URL is<br>
                    <a href="http://www.pageoftext.com/PH_show_page&nm_page=$page_name&nm_no_opts=1">http://www.pageoftext.com/PH_show_page&nm_page=$page_name&nm_no_opts=1</a>
                </p>
            </div>

            <div style="margin-bottom:30px;"><strong>Free and Open Source Software</strong>
                <p style="margin-left:20px;">All of the code which runs this site is free and open source software.  The bulk is licensed under the GPLv2.  Some of the modules are licensed under the UGPL or the more permissive Artistic license.</p>
                <p style="margin-left:20px;">The code will only work on UNIX type platforms.</p>
                <p style="margin-left:20px;">I also include the Selenium browser tests for the site.</p>
                <p style="margin-left:40px;">It is hosted at: <a href="http://code.google.com/p/potoss/">http://code.google.com/p/potoss/</a></p>
                <p style="margin-left:40px;">There is also a pageoftext page about the project, <a href="http://www.pageoftext.com/potoss">www.pageoftext.com/potoss</a></p>
            </div>
        </div>
    ~;

    my $body = qq~
        <p style="margin-bottom:20px;"><a href="./?$page_name">go back to the page</a></p>
        $sub_nav
        <div style="border:1px; border-color:#ccc; border-style:solid; margin-top:4px; padding:10px;">
            $message
        $text_for_level{$level}
    ~;

    hprint($body, { page_name => $page_name, sub_page_name => "options" });
}

sub _calculate_linkable_pages_cache {
    # Calculate all the page names and cache them.
    my @pages = map( { s/_FOPT_allows_incoming_links$//; $_ } split(/\n/, `cd $conf{CNF_TEXTS_DIR}; ls *_FOPT_allows_incoming_links`) );
    my $linkable_pages = join("\n", sort(@pages));
    Potoss::File::write_file("$conf{CNF_CACHES_DIR}/linkable_pages", $linkable_pages);
}

sub _calculate_alias_pages_cache {
    # Calculate all the page names and cache them.
    my @pages = map( { s/_ALIAS$//; $_ } split(/\n/, `cd $conf{CNF_TEXTS_DIR}; ls *_ALIAS`) );
    my $alias_pages = join("\n", sort(@pages));
    Potoss::File::write_file("$conf{CNF_CACHES_DIR}/alias_pages", $alias_pages);
}

sub page_fopt {
    my $page_name = shift;
    my $get_create_or_remove = shift;
    my $opt = shift;
    my $value = shift || '';

    my %fopts = get_fopts();

    #start_of_strict_tests-can_remove_for_performance

    if (! _is_in_set($get_create_or_remove, qw(get create remove exists)) ) {
        throw("get_create_or_remove must be [get create remove exists] not $get_create_or_remove");
    }

    if (! _is_in_set($opt, sort keys %fopts) ) {
        throw("option $opt is not a valid page option");
    }

    #end_of_strict_tests-can_remove_for_performance



    my $filename = "$conf{CNF_TEXTS_DIR}/${page_name}_FOPT_$opt";

    if ($get_create_or_remove eq 'exists') {
        return 1 if -e $filename;
        return 0;
    }
    if ($get_create_or_remove eq 'get') {
        return '' if ! -e $filename;
        my $value = Potoss::File::read_file($filename, $value);
        return $value;
    }
    if ($get_create_or_remove eq 'create') {
        Potoss::File::write_file($filename, $value);
        return 1;
    }
    if ($get_create_or_remove eq 'remove') {
        unlink($filename);
        return 1;
    }
}

sub get_fopts {
return (
    has_linking => {
        level => 'more',
        data_type => 'bool',
        yes_message =>
            "Any links to other pages will now be <strong>visible</strong>",
        no_message =>
            "Any links to other pages will now be <strong>hidden</strong>",
            no_link => "in the page's text, <strong>hide</strong> any links to other pages",
            yes_link => "in the page's text, <strong>show</strong> any links to other pages",
    },
    allows_incoming_links => {
        level => 'more',
        data_type => 'bool',
        yes_message =>
            qq~
            Other pages may now link to this page.<br>
            Just add the page name in brackets [pagename] to the other page and
            it will create a link to this page
            ~,
        no_message =>
            "Other pages are now <strong>not</strong> allowed to link to this page",
            no_link => "<strong>do not</strong> allow other pages to link to this one",
            yes_link => "allow other pages to link to this one",
    },
    show_encryption_buttons => {
        level => 'very',
        data_type => 'bool',
        yes_message => "The encryption buttons are now <strong>shown</strong> on the page",
        no_message => "The encryption buttons are <strong>no longer</strong> shown on the page",
            no_link => "<strong>hide</strong> the encryption buttons",
            yes_link => "<strong>show</strong> the encryption buttons",
    },
    show_search_box => {
        level => 'more',
        data_type => 'bool',
        yes_message => "The search box is now <strong>shown</strong> on the page",
        no_message => "The search box is <strong>no longer</strong> shown on the page",
            no_link => "<strong>hide</strong> the search box",
            yes_link => "<strong>show</strong> the search box",
    },
    has_no_text_wrap => {
        level => 'more',
        data_type => 'bool',
        yes_message =>
            "The text is <strong>no longer</strong> wrapped at 80 characters",
        no_message =>
            "The text has been <strong>wrapped</strong> at 80 characters",
            no_link => "<strong>wrap</strong> the text",
            yes_link => "<strong>unwrap</strong> the text",
    },
    hide_from_find => {
        level => 'more',
        data_type => 'bool',
        yes_message =>
            "The page is <strong>no longer</strong> shown in the 'find a page' results",
        no_message =>
            "The page is now <strong>shown</strong> in the 'find a page' results",
            no_link => "<strong>show</strong> the page from the 'find a page' results",
            yes_link => "<strong>hide</strong> the page in the 'find a page' results",
    },
    use_recaptcha => {
        level => 'more',
        data_type => 'bool',
        yes_message =>
            "The text is now <strong>using</strong> reCAPTCHA",
        no_message =>
            "The text is now <strong>not</strong> using reCAPTCHA",
            no_link => "do <strong>not</strong> use reCAPTCHA",
            yes_link => "<strong>use</strong> reCAPTCHA",
    },
    use_creole => {
        level => 'more',
        data_type => 'bool',
        yes_message =>
            "The text is now <strong>using</strong> the Creole markup language",
        no_message =>
            "The text is now <strong>not</strong> using the Creole markup language",
            no_link => "do <strong>not</strong> use the Creole markup language",
            yes_link => "<strong>use</strong> the Creole markup language",
    },
    remove_branding => {
        level => 'very',
        data_type => 'bool',
        yes_message =>
            "The branding has been <strong>removed</strong> from the page",
        no_message =>
            "The branding is now <strong>showing</strong> on the page",
            no_link => "<strong>show</strong> the branding",
            yes_link => "<strong>remove</strong> the branding",
    },
    remove_create_new_link => {
        level => 'very',
        data_type => 'bool',
        yes_message =>
            "The 'create new page' link has been <strong>removed</strong> from the page",
        no_message =>
            "The 'create new page' link is now <strong>showing</strong>",
            no_link => "<strong>show</strong> the 'create new page' link",
            yes_link => "<strong>remove</strong> the 'create new page' link",
    },
    remove_container_div => {
        level => 'very',
        data_type => 'bool',
        yes_message =>
            "The container div has been <strong>removed</strong> from the page",
        no_message =>
            "The container div is now <strong>used</strong>",
            no_link => "<strong>use</strong> the container div",
            yes_link => "<strong>remove</strong> the container div",
    },
    bar_color_hex => {
        level => 'very',
        data_type => 'color',
        set_message => "The bar's color was set.",
    },
    read_only_aliases => {
        level => 'very',
        data_type => 'read_only_page_name_list',
        set_message => "The read-only aliases were set.",
    },

);
}

sub _is_in_set {
    my $value = shift;
    my @set = @_;
    return grep({ $_ eq $value} @set) ? 1 : 0;
}

sub PH_page_revisions {
    my $page_name = $cgi->param("nm_page");
    my $mode = $cgi->param("nm_mode") || '';

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    my $body = '';

    my $compare_start = $cgi->param("nm_compare_start") || -1;
    my $compare_end = $cgi->param("nm_compare_end") || -1;

    my $latest_revision = get_page_HEAD_revision_number($page_name, 'cached');

    my @revs = ();

    my @compare_start = ();
    my @compare_end = ();

    REVISION:
    for my $rev (0..$latest_revision) {
        my $revision_or_head = $rev;
        if ($revision_or_head == $latest_revision){
            $revision_or_head = "HEAD";
        }
        my $filename = get_filename_for_revision($page_name, $rev);
        my $modified = -M $filename;
        if ($modified < 0.0001) {
            # gemhack 4 - catches weird formatting errors
            # for a really small number.
            $modified = 0;
        }
        else {
            $modified =~ m{(.*\......)};
            $modified = $1;
        }

        my $compare = '';
        if ($latest_revision > 0 && $mode eq "compare"){
            
            next REVISION if $rev == 0;
            if ($rev < $latest_revision) {
                push @compare_start, qq~
                    <p><a href="./?PH_page_revisions&nm_page=$page_name&nm_mode=compare&nm_compare_end=$compare_end&nm_compare_start=$rev">start at revision $rev</a> - $modified days ago</p>
                ~;
            }
            if ($rev > $compare_start) {
                push @compare_end, qq~
                    <p><a href="./?PH_page_revisions&nm_page=$page_name&nm_mode=compare&nm_compare_end=$rev&nm_compare_start=$compare_start">end at revision $rev</a> - $modified days ago</p>
                ~;
            }
        }
        else {
            next REVISION if $rev == 0;
            push @revs, qq~
                <p><a href="./?PH_show_page&nm_page=$page_name&nm_rev=$revision_or_head">view revision $rev - $modified days ago</a></p>
            ~;

        }
    }

    push @compare_start, qq~<p>&nbsp;</p>~;

    if ($latest_revision > 0 && $mode eq "compare"){
        if ($compare_start == -1 || $compare_end == -1){

            my $start = join("\n", reverse @compare_start);
            my $end = join("\n", reverse @compare_end);

            my $pick_start_or_end = '';
            if ($compare_start == -1) {
                $pick_start_or_end = qq~<tr><td style="color:red;background-color:#ccc;">pick a start</td><td>&nbsp;</td></tr>~;
            }
            else {
                $pick_start_or_end = qq~<tr><td>&nbsp;</td><td style="color:red;background-color:#ccc;">pick an end</td></tr>~;
            }

            $body = qq~
                <table>
                    $pick_start_or_end
                    <tr><td style="padding:20px;vertical-align:top;">$start</td><td style="padding:20px;vertical-align:top;">$end</td></tr>
                </table>
            ~;
        }
        else {
            my $start_file = get_filename_for_revision($page_name, $compare_start);
            my $end_file = get_filename_for_revision($page_name, $compare_end);

            my $diff = _diff_files($start_file, $end_file);
            $body = _encode_entities($diff);
            $body =~ s/\n/<br>/g;

            $body = qq~
                <p style="background-color:#ccc;">Changes between revisions $compare_start and $compare_end</p>

                <p><em>Some day soon this will look all fancy with colors.  For now it's just a text diff.</em></p>

                $body
            ~;
        }

    }
    else {
        $body = join("\n", reverse @revs);
    }

    if ($latest_revision < 2 && $mode eq ''){
        $body = qq~
            <p style="margin-bottom:30px;"><a href="./?PH_page_opts&nm_page=$page_name">go back to the advanced menu</a></p>
            
            <p>There is currently only one revision, which is the current one.</p>
            <p>As you edit the page, each time you save it a new revision will be saved.</p>
            <p>When there is more than one revision you'll be able to compare revisions here.</p>
        ~;
        hprint($body, { page_name => $page_name, sub_page_name => "revisions" });
        return;
    }

    my $compare = "";
    if ($latest_revision > 1 && $mode eq ''){
        $compare = qq~<p style="margin-bottom:30px;"><a href="./?PH_page_revisions&nm_page=$page_name&nm_mode=compare">compare two revisions</a></p>~;
    }

    $body = qq~
        <p style="margin-bottom:30px;"><a href="./?PH_page_opts&nm_page=$page_name">go back to the advanced menu</a></p>
        $compare
        $body
    ~;

    hprint($body, { page_name => $page_name, sub_page_name => "revisions" });
}


sub PH_page_submit {
    my $page_name = $cgi->param("nm_page");
    my $text = $cgi->param("nm_text");
    my $head_revision_number_at_edit_start = $cgi->param("nm_head_revision_number_at_edit_start");
    my $no_opts = $cgi->param('nm_no_opts') || 0;
    my $skip_revision_num_check = $cgi->param('nm_skip_revision_num_check') || 0; #aka ignore or bypass

    my $no_opts_str = ($no_opts) ? "&nm_no_opts=1" : '';

    if (page_fopt($page_name, 'exists', "use_recaptcha")) {
        _validate_recaptcha_or_throw();
    }

    if (! $skip_revision_num_check ) {
        if (get_page_HEAD_revision_number($page_name, 'cached') != $head_revision_number_at_edit_start) {
            throw(
                qq~<p>Someone wrote a version of the text between when you hit
                'edit' and submitted your change.<br>
                If we were to save your edit, we would completely wipe out their edit.</p>
                <p>
                You can avoid this problem by making quick edits or not having
                too many people working on a page at the same time.</p>
                <p><a href="./?PH_edit&nm_rev=HEAD&nm_page=$page_name$no_opts_str" style="margin-right:40px;">Redo the edit starting from the latest revision</a></p>
                <p><a href="./?PH_show_page&nm_page=$page_name&nm_rev=HEAD$no_opts_str" style="margin-right:40px;">Go to the latest revision of the page</a></p>
                ~
            );
        }
    }

    _write_new_page_revision($page_name, $text);

    if ($no_opts) {
        do_redirect("./?PH_show_page&nm_page=$page_name$no_opts_str");
    }
    else {
        do_redirect("./?$page_name");
    }
}

sub semiRandText {
    my $length = shift;
    my $result = "";
    while (length($result) < $length){
        my $int = int(rand(32000));
        $int =~ tr/0-9/a-j/;
        $result .= $int;
        $result = substr($result, 0, $length);
    }
    return $result;
}

sub PH_pages_tgz {
    my $page_names = $cgi->param("nm_pages") || shift;

    my @pages = split(/-/, $page_names);

    if (! @pages) {
        throw('must have at least one page to tar and zip');
    }

    _all_pages_exist_or_throw('in PH_pages_tgz', @pages);

    my $foldername = "tar_" . semiRandText(20);

    _tgz_pages($foldername, @pages);

    my $plural_s = (scalar(@pages) > 1) ? 's' : q[];
    my $plural_ve = (scalar(@pages) > 1) ? 's' : 've';

    my $body = qq~
        <p>The page$plural_s (with all the options and revisions) ha$plural_ve been turned into a tgz file (a zipped tar file)</p>
        <p>You can download the file <a href="./$foldername.tgz">here</a></p>
    ~;
    hprint($body, { special_page_name => "tar file" });
}

sub _page_exists {
    my $page_name = shift;

    if (! $page_name) {
        return 0;
    }

    my $filename = get_filename_for_revision($page_name, "HEAD");

    if (-e $filename) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _all_pages_exist_or_throw {
    my $throw_message = shift;
    my @pages = @_;

    # Check that all the page names are OK
    for my $page_name (@pages) {
        if (! _page_exists($page_name)) {
            throw("page $page_name doesn't exist - $throw_message");
        }
    }
}

sub _tgz_pages {
    # For a set of pages, tar all the files associated with the pages.

    my $foldername = shift;

    my @pages = @_;

    _all_pages_exist_or_throw('in _tgz_pages', @pages);

    `mkdir $conf{CNF_ROOT_DIR}/$foldername`;

    # Note, A-Z was interpolating into a case insensitive match when Perl
    # shelled out.  Thus, we use every character instead of the A-Z shorthand.
    my $capital_a_thru_z = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    for my $page_name (@pages) {
        `cp -a $conf{CNF_TEXTS_DIR}/${page_name}_[$capital_a_thru_z]* $conf{CNF_ROOT_DIR}/$foldername`;
        # gemhack 4 - remove any subversion files... ugh.
        `rm -rf $conf{CNF_ROOT_DIR}/$foldername/${page_name}_REVS/.svn`;
    }

    `cd $conf{CNF_ROOT_DIR}/$foldername; tar -cvzf "../$foldername.tgz" *; cd ..; rm -r $foldername`;
}

sub _write_new_page_revision {
    my $page_name = shift;
    my $text = shift;

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    # Write the HEAD file

    my $filename = "$conf{CNF_TEXTS_DIR}/$page_name";
    Potoss::File::write_file($filename . "_HEAD", $text);

    # Now write the revision file to the ${page_name}_REVS folder

    my $rev = get_page_HEAD_revision_number($page_name, 'cached') + 1;

    # If this page is just being created, then see if it should default to
    # being formatted as creole.
    if ($rev == 0
        && exists $conf{CNF_DEFAULT_PAGE_FORMAT}
        && $conf{CNF_DEFAULT_PAGE_FORMAT} eq 'creole') {

        page_fopt($page_name, 'create', 'use_creole');

    }

    my $page_rev = "${page_name}_R$rev";

    my $revs_dir = "${filename}_REVS";
    mkdir($revs_dir) if (! -d $revs_dir);
    my $rev_filename = "$revs_dir/$page_rev";
    Potoss::File::write_file($rev_filename, $text);

    # Writing stuff to a backup directory is an extra precaution
    # against data loss.
    my $backup_dir = "$conf{CNF_TEXTS_BACKUP_DIR}";
    mkdir($backup_dir) if (! -d $backup_dir);
    my $time = time(); # The time adds a bit of randomness to the end
    Potoss::File::write_file("$backup_dir/${page_rev}_$time", $text);
    
    set_page_HEAD_revision_number_cache($page_name, $rev);

    _links_out_cache_file_create_or_update($page_name);

}

sub get_filename_for_revision {
    my $page_name = shift;
    my $revision = shift || 'HEAD';

    $page_name = _resolve_alias($page_name) || $page_name;

    if ($revision eq 'HEAD') {
        $revision = get_page_HEAD_revision_number($page_name, 'cached');
    }

    my $filename = "$conf{CNF_TEXTS_DIR}/${page_name}_REVS/${page_name}_R$revision";
    return $filename;
}

#sub _update_alias {
#    my $page_name = shift;
#    my $mode = shift;
#
#    if (! _is_in_set($mode, qw(deactivate reactivate)) ) {
#        throw("mode must be deactivate or reactivate");
#    }
#
#    my $filename = "$conf{CNF_TEXTS_DIR}/$page_name";
#    my $alias_file = $filename . "_ALIAS";
#    my $deactivated_alias_file = $filename . "_ALIAS_DEACTIVATED";
#
#    if ($mode eq 'deactivate') {
#        if (-e $deactivated_alias_file) {
#            throw("the alias is already deactivated");
#        }
#
#        if (! -e $alias_file){
#            throw("the alias file does not exist");
#        }
#
#        `mv $alias_file $deactivated_alias_file`;
#    }
#    elsif ($mode eq 'reactivate') {
#        if (-e $alias_file) {
#            throw("the alias is already activated");
#        }
#
#        if (! -e $deactivated_alias_file){
#            throw("there is not deactivated alias to activate");
#        }
#
#        `mv $deactivated_alias_file $alias_file`;
#    }
#    
#    return 1;
#}
#
#sub _aliases_to_page {
#    my $page_name = shift;
#
#    my @active_aliases = split(/\n/, `cd $conf{CNF_TEXTS_DIR}; ls *_ALIAS`);
#    my @non_active_aliases = split(/\n/, `cd $conf{CNF_TEXTS_DIR}; ls *_ALIAS_DEACTIVATED`);
#
#    my @all = map( { s/_ALIAS$//; $_ } split(/\n/, `cd $conf{CNF_TEXTS_DIR}; ls *_ALIAS`) );
#
#    my $alias_pages =Potoss::File::read_file("$conf{CNF_CACHES_DIR}/alias_pages");
#
#    my @matching_aliases = ();
#
#    my @aliases = split("\n", $alias_pages);
#
#    for my $alias_file (@aliases) {
#        my $target_page_name = Potoss::File::read_file($alias_file . "_ALIAS");
#        chomp($target_page_name);
#        if ($target_page_name eq $page_name) {
#            push @matching_aliases, $alias_file;
#        }
#    }
#
#    return @matching_aliases;
#
#}

sub get_page_HEAD_revision_number {
    my $page_name = shift;
    my $real_or_cached = shift;

    if (! _is_in_set($real_or_cached, qw(real cached)) ) {
        throw("real_or_cached must be real or cached, not $real_or_cached");
    }

    if ($real_or_cached eq 'cached') {
        my $file = "$conf{CNF_TEXTS_DIR}/${page_name}_HREV";
        if (-e $file) {
            return Potoss::File::read_file("$conf{CNF_TEXTS_DIR}/${page_name}_HREV");
        }
        else {
            return -1;
        }
    }

    #gemhack 3 - If there are more than 10,000,000 revisions, this will fail.
    for my $revision (0..10_000_000) {
        my $filename = "$conf{CNF_TEXTS_DIR}/${page_name}_REVS/${page_name}_R$revision";
        if (! -e $filename){
            return $revision -1;
        }
    }

    return 0;
}

sub set_page_HEAD_revision_number_cache {
    my $page_name = shift;
    my $revision = shift;
    Potoss::File::write_file("$conf{CNF_TEXTS_DIR}/${page_name}_HREV", $revision);
}

sub PH_redirect_test {
    do_redirect("./?potoss_saved_test");
}

sub do_redirect {
    my $location = shift;
    if ($ENV{SERVER_SOFTWARE} =~ m{HTTP::Server::Simple}) {
        print "HTTP/1.1 302 Found\r\n";
    }
    filter_print("Location: $location\n\n");
}

sub hprint {
    my $bodytext = shift;
    my $arg_ref = shift || {};

    my $maybe_create_page_js        = '';
    my $maybe_blowfish_js           = '';
    my $maybe_keys_js               = '';
    my $maybe_universal_edit_button = '';
    my $maybe_rss_button            = '';
    my $maybe_sortable_table        = '';
    my $maybe_keys_palette_div      = '';

    my $page_title = ($arg_ref->{page_name})
        ? "page: $arg_ref->{page_name}"
        : $conf{CNF_SITE_READABLE_NAME};

    if ( $arg_ref->{sub_page_name} ) {
        $page_title .= " - " . $arg_ref->{sub_page_name};
    }

    if ( $arg_ref->{special_page_name} ) {
        $page_title = $conf{CNF_SITE_READABLE_NAME} . " - " . $arg_ref->{special_page_name};
    }
    
    if ($arg_ref->{add_rss_to_head}) {
        # or maybe go directly to the diffs only page
        #./?PH_rss&nm_pages=$arg_ref->{page_name}&nm_rss_mode=diffs_only
        $maybe_rss_button = qq~
            <link rel="alternate" type="application/rss+xml" title="pageoftext.com: $arg_ref->{page_name}" href="./?PH_choose_rss&nm_pages=$arg_ref->{page_name}" />
        ~;
    }
    
    if ($arg_ref->{universal_edit_button_url}) {
        # the url is passed in rather than created here because there is some
        # logic involved in its creation.
        $maybe_universal_edit_button = qq~
            <link rel="alternate" type="application/wiki" title="Edit this page!" href="$arg_ref->{universal_edit_button_url}" />
        ~;
    }

    if ($arg_ref->{add_create_page_js}) {

        my @names = (
            [qw(a many)],
            [qw(green yellow red blue purple violet pink black white silver gold beige)],
            [qw(bumpy large round floppy smooth bold sly shy mean happy slow angry smart)],
            [qw(dog cat bird unicorn cougar elephant lion bear worm dolphin cheetah)],
            [qw(laughing smiling arguing listening growling sneering cheating snickering eating walking groaning)],
        );

        my @chunks = ();
        for my $position (0..4) {
            my @opts = @{$names[$position]};

            my $value = $opts[rand(scalar(@opts))];

            # make the animal plural if you need to
            if ($position == 3){
                if ($chunks[0] eq 'many'){
                    $value .= "s";
                }
            }

            push @chunks, $value;
        }

        my $generated_name = join("_", @chunks);

        $maybe_create_page_js = qq~
            <script type="text/javascript" language="javascript">
                function fill_in_name() {
                  var v_oElement = document.getElementById("myel_page_name");
                  v_oElement.value = "$generated_name";
                }
            </script>
        ~;

    }

    if ($arg_ref->{add_blowfish_js}) {

        # [tag:compatibility:gem]
        # gemhack 5 - If you change the following to be XMTML, it will fail
        # in Internet Explorer 7 for some odd reason.  Don't do it!
        my $do_not_change_formatting_of_script_include = qq~
            <script src="./static/blowfish.js" type="text/javascript"></script>
        ~;

        $maybe_blowfish_js = qq~
            <script type="text/javascript" language="javascript">

                function is_text_encrypted () {

                    var ps = "";

                    //Works with either the text in edit mode or in view mode
                    if ( document.getElementById('myel_text_area') ) {
                        ps = document.getElementById('myel_text_area').value;
                    }
                    else if ( document.getElementById('myel_text') ) {
                        ps = document.getElementById('myel_text').innerHTML;
                        ps = ps.replace(/<br>/ig, "");
                    }

                    if ( ps.match(/^[0-9A-F]+\$/) == undefined ) {
                        return 0;
                    }

                    return 1;
                }

                function only_submit_if_textarea_encrypted () {
                    var ps = document.getElementById('myel_text_area').value;
                    if ( is_text_encrypted() == 0 ) {
                        confirm("The text appears to not be encrypted.  Are you sure you want to save?")
                            && document.getElementById('fr_edit_page').submit();
                    }
                    else {
                        document.getElementById('fr_edit_page').submit();
                    }
                }

                function enter_was_typed_in_blowfish_key_input () {
                    if ( is_text_encrypted() ) {
                        do_blowfish('decrypt', document.getElementById('myel_blowfish_key').value);
                    }
                    else {
                        // Only actually encrypt if you happen to be in the "edit" page.
                        // It doesn't make much sense in the "view" page.
                        if ( document.getElementById('myel_text_area') ) {
                            do_blowfish('encrypt', document.getElementById('myel_blowfish_key').value);
                        }
                    }
                }

                function do_blowfish (x_sMode, x_sKey) {

                    if (x_sKey == 'some_key') {
                        alert('Use a key other than some_key, which is very guessable.');
                        return;
                    }

                    if (x_sKey == '') {
                        alert('The key should not be blank.');
                        return;
                    }

                    var tarea = document.getElementById('myel_text_area');
                    var textp = document.getElementById('myel_text');

                    var bf = new Blowfish(x_sKey);

                    if (x_sMode == 'encrypt') {
                        if (tarea) {
                            tarea.value = bf.encrypt(tarea.value);
                        }
                        else {
                            textp.innerHTML = bf.encrypt(textp.innerHTML);
                        }
                    }
                    else {
                        var plaintext = '';

                        if (tarea) {
                            plaintext = bf.decrypt(tarea.value);
                        }
                        else {
                            //It could be a long, wrapped, ciphertext, so remove the <br>s
                            var ciphertext = textp.innerHTML;
                            ciphertext = ciphertext.replace(/<br>/ig, "");
                            plaintext = bf.decrypt(ciphertext);
                            plaintext = plaintext.replace(/\\n/g, "<br>");
                        }

                        // After decryption there may be some padding characters.
                        // Strip them.
                        for(j=0;j<7;j++){
                            if (plaintext.charCodeAt(plaintext.length - 1) == 0) {
                                plaintext = plaintext.substr(0, plaintext.length - 1);
                            }
                        }

                        (tarea)
                            ? tarea.value = plaintext
                            : textp.innerHTML = plaintext;
                    }
                }
            </script>
            $do_not_change_formatting_of_script_include
        ~;
    }

    if ($arg_ref->{add_sortable_table_js}) {
        $maybe_sortable_table = qq~<script src="./static/sorttable.js" type="text/javascript"></script>~;
    }

    if ($arg_ref->{add_keys_js}) {

        # [tag:compatibility:gem]
        # gemhack 5 - If you change the following to be XMTML, it will fail
        # in Internet Explorer 7 for some odd reason.  Don't do it!
        my $do_not_change_formatting_of_script_include = qq~
            <script src="./static/keys3.js" type="text/javascript"></script>
        ~;

        $maybe_keys_js = qq~
            <script type="text/javascript" language="javascript">
                function get_pagename () {
                    return "$arg_ref->{page_name}";
                }
            </script>
            $do_not_change_formatting_of_script_include
        ~;
        $maybe_keys_palette_div = qq~<div id="myel_keys_palette" style="position:absolute;top:40px;left:-1000px;background-color:#eee;padding:2px;">&nbsp;</div>~;
    }

    my $doubleclick_js = qq~
        <script type="text/javascript" language="javascript">
           function double_click_to_edit () {
                var edit_btn = document.getElementById('myel_edit_link');
                document.location = edit_btn.href;
            }
        </script>
    ~;

    #$arg_ref->{debug_info} = "params: " . join('', $cgi->param());

    my $debug_info = ($arg_ref->{debug_info}) ? $arg_ref->{debug_info} : '';

    my $main_border = 'border: 1px solid #ccc;';
    if ($arg_ref->{remove_border}) {
        $main_border = '';
    }

    my $branding = qq~
        <div style="margin-bottom:10px;background-color:#eee;">
            <a href="./?" class="pot" style="font-size:9px;text-decoration:none;">$conf{CNF_SITE_READABLE_NAME}</a>
        </div>
    ~;
    $branding = "" if $arg_ref->{remove_branding};

    my $start_container_div = qq~<div style="width:600px;padding:10px;$main_border">~;
    my $end_container_div = qq~</div>~;

    $start_container_div = '' if $arg_ref->{remove_container_div};
    $end_container_div = '' if $arg_ref->{remove_container_div};

    if ($ENV{SERVER_SOFTWARE} =~ m{HTTP::Server::Simple}) {
        print "HTTP/1.0 200 OK\r\n";
    }
    print $cgi->header(-expires => '-1d');

    my $document_start = qq~<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
   "http://www.w3.org/TR/html4/loose.dtd"><html><head><title>$page_title</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<link rel="stylesheet" href="$conf{CNF_STYLE_SHEET}" type="text/css" />
~;

    my $document_end = qq~
    </body>
</html>
    ~;

    if ($arg_ref->{stylesheet_only}) {
        filter_print(qq~$document_start
        </head>
        <body style="margin-left:10px;">
        $bodytext
        $document_end~);
    }
    else {
        # [tag:performance:gem] This looks somewhat obfuscated because
        # indenting takes up more bandwidth.
        filter_print(qq~$document_start
    $doubleclick_js
    $maybe_create_page_js
    $maybe_blowfish_js
    $maybe_keys_js
    $maybe_sortable_table
        <script>
            function do_onload () {
                if ( document.getElementById('myel_blowfish_key') ) {
                    document.getElementById('myel_blowfish_key').focus();
                }
                else if ( document.getElementById('myel_text_area') ) {
                    document.getElementById('myel_text_area').focus();
                }
                else if ( document.getElementById('myel_search_query') ) {
                    document.getElementById('myel_search_query').focus();
                }
                else if ( document.getElementById('myel_page_name') ) {
                    document.getElementById('myel_page_name').focus();
                }
            }
        </script>
    $maybe_universal_edit_button
    $maybe_rss_button
    </head>
    <body style="margin-left:10px;" onload="do_onload()">
    $start_container_div
    $branding
    <div id="myel_bodytext" ondblclick="double_click_to_edit()">$bodytext</div>
    $end_container_div
    $maybe_keys_palette_div
    $debug_info
    $document_end~);
    }
}

sub filter_print {
    my $text = shift;

    # See the configuration file for more details about this option.
    # It has to do with keeping the URLs clean, but requires Mod_Rewrite
    # in Apache.
    if ($conf{CNF_SHOULD_STRIP_QUESTION_MARKS}){
        $text =~ s{\./\?}{./}g;
        $text =~ s{/\?PH_}{/PH_}g;
        $text =~ s{$conf{CNF_SITE_BASE_URL}/\?}{$conf{CNF_SITE_BASE_URL}/}g;
    }

    print $text;

}

#-----------------------------------------------------------------------------
# sect: libraries
#-----------------------------------------------------------------------------

sub _compat_require_file_find {
    # [tag:compatibility:gem] - we might want to allow for Win32 later,
    # so use as few shell commands as possible.  So, require File::Find.
    # Do this in a subroutine so we only have to put this note in one place.
    require File::Find;
}

#-----------------------------------------------------------------------------
# sect: test support
#-----------------------------------------------------------------------------

sub _test_num_pages {
    # Get the number of pages which match a quoted regex.
    # Or all the pages.
    # Every page has a HEAD version, so that's a good filename
    # to test for.

    my $qr = shift || '';

    _compat_require_file_find();

    my $cnt = 0;

    File::Find::find (sub {
        return if $_ !~ /_HEAD$/;
        if ($qr) {
            return if $_ !~ $qr;
        }
        $cnt++;
    }, $conf{CNF_TEXTS_DIR});

    return $cnt;
}

sub _test_num_fopts {
    # Get the number of fopts which match a quoted regex.

    my $qr = shift
        || die "need a regex for num of fopts";

    my $cnt = 0;

    _compat_require_file_find();

    File::Find::find (sub {
        return if $_ !~ /_FOPT_/;
        if ($qr) {
            return if $_ !~ $qr;
        }
        $cnt++;
    }, $conf{CNF_TEXTS_DIR});

    return $cnt;
}

sub _test_delete_page {
    # This subroutine deletes all the files associated with a page.
    # It's listed as test, because we'll be creating and deleting pages
    # in the test script.

    my $page_name = shift;
    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    # First, delete all the REV files, then the REVS folder.
    my $revs_dir = "$conf{CNF_TEXTS_DIR}/${page_name}_REVS";

    _compat_require_file_find();

    File::Find::find (sub {
        unlink($_);
    }, $revs_dir);
    rmdir($revs_dir);


    # All the other page associated files: the FOPTS, HEAD, and HREV
    # follow a pattern, so they are easy to find and delete.
    # See the regex below.
    File::Find::find (sub {
        if ($_ =~ m{^${page_name}_[A-Z]}) {
            unlink($_);
        }
    }, $conf{CNF_TEXTS_DIR});
}

#TEMPLATE_ADD_PAGEOFTEXTCOM_SUBS

1;
