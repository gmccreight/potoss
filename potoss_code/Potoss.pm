package Potoss;

# POTOSS (The source of pageoftext.com)

use strict;
use warnings;

#use Time::HiRes qw(tv_interval gettimeofday);

require PotConf;

no warnings;
# Share the configuration because the .t file uses it as well.
our %conf = %PotConf::conf;
use warnings;

my $cgi;

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
        push @p, $cgi->param("keywords");
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
    my $body = qq~
        <p>Welcome!</p>

        <a href="./?PH_create">create a new <span class="pot">page of text</span></a> to edit by yourself or with others

        <p>or</p>

        <a href="./?PH_help_find">help me find a page I already created</a>
    ~;
    hprint($body);
}

sub PH_help_find {
    my $body = qq~

        <p style="margin-bottom:20px;">This form will send an email to a real person ($conf{CNF_ADMIN_FULL_NAME}... that's me!)</p>

        <form id="fr_create" method="post" action="./?">
            <input type="hidden" name="PH_help_find_submit" value="1">
            
            <div style="margin-bottom:8px;">What is your email address?</div>
            <div style="margin-bottom:20px;"><input type="text" name="nm_from_address" value="" class="form" style="width:200px"></div>

            <div style="margin-bottom:8px;">Describe the page in detail (like you're describing your lost wallet, trying to convince $conf{CNF_ADMIN_FIRST_NAME} it's yours)  Include any keywords $conf{CNF_ADMIN_HE_OR_SHE} might look for, etc.</div>
            <textarea id="myel_text_area" name="nm_description" cols="80" rows="16" style="font-size:12px;"></textarea>

            <div><input type="submit" name="nm_submit" value="send it" class="form"></div>
        </form>
    ~;
    hprint($body);
}

sub PH_help_find_submit {

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

    hprint($body);
}

sub PH_create {
    my $page_name = $cgi->param("nm_page") || "";
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
            
            <div style="margin-bottom:8px;">What would you like the page name to be? (may only contain a-z, 0-9, and underscores)</div>
            <div style="margin-bottom:8px;">Like: <span style="color:#448;margin-left:10px;margin-right:10px;">mom_birthday_2007</span> or <span style="color:#448;margin-left:10px;">meeting_notes_070305</span></div>
            <div style="margin-bottom:8px;">If you don't want strangers to look at and possibly edit your page,<br>name it something unique and non-guessable.</div>
            <div style="margin-bottom:10px;"><input id="myel_page_name" type="text" name="nm_page" value="$page_name_for_form" class="form" style="width:300px"> <a href="javascript:fill_in_name();">suggest a name</a></div>
            <div><input type="submit" name="nm_submit" value="create the page" class="form"></div>
        </form>
    ~;
    hprint($body, {add_create_page_js => 1});
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
    hprint($body);

    # Abort the rest of the processing, but use "die" because it
    # allows the HTTP::Server::Simple to trap and continue running.
    die;
}

sub PH_create_submit {
    my $page_name = $cgi->param("nm_page");

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
        
    my $body = qq~
        <p style="color:#696;">Great!</p>
        <p>The URL to the new page is <a id="myel_new_page" href="./?$page_name">http://$conf{CNF_SITE_BASE_URL}/?$page_name</a></p>
        <p><span style="color:red;">Don't lose the URL</span>.  It functions like a password.</p>
        <p>This is the URL which you will give to people who you want to edit the page with.</p>
        <p>You should <strong>bookmark it</strong> so you don't forget it.</p>
        
    ~;
    _write_new_page_revision($page_name, '');

    hprint($body);
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
        print _read_file($filename);
    }
}

sub _encode_entities {
    my $data = shift;
    require HTML::Entities;
    return HTML::Entities::encode($data);
}

sub _wrap_text {
    my $text = shift;

    # gemhack 5 - This is a patched version [tag:patched]
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
            
            my $page_data = _read_file($filename);

            # make it case-insensitive
            my $lc_search_query = lc($search_query);
            $page_data = lc($page_data);

            if ($page_data !~ m{$lc_search_query}) {
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

    my $rss_feed_icon = qq~<a href="./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=$prune_list&nm_sort_by=$sort_by&nm_mode=rss" style="margin-right:20px;">
        rss feed <img src="./static/rss.jpg" height="12" width="12" border="0"/>
    </a>~;

    my $tgz_link = qq~<a href="./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=$prune_list&nm_sort_by=$sort_by&nm_mode=tgz">
        create a backup tarball
    </a>~;

    my $unprune_all_link = '';
    if (@prune_list_array) {
        $unprune_all_link = qq~<a href="./?PH_page_links&nm_page=$page_name&nm_search_query=$search_query&nm_max_depth=$max_depth&nm_prune_list=&nm_sort_by=$sort_by">unprune all</a>~;
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
            
        <h4>Links for: <a href="./?$page_name">$page_name</a></h4>
        $maybe_search_results

        <form id="fr_search_links" method="post" action="./?" style="margin-bottom:20px;">
            <input type="hidden" name="PH_page_links" value="1">
            <input type="hidden" name="nm_page" value="$page_name">
            <input type="hidden" name="nm_prune_list" value="$prune_list">
            <input type="hidden" name="nm_sort_by" value="$sort_by">
            search pages for: <input type="text" name="nm_search_query" value="$search_query" style="width:200px;margin-right:20px;">
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
        hprint($body);
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
            PH_rss($pages_str);
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
    
    my $page_data = _read_file($filename);

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
    _write_file($filename . "_CACHE_possible_links_out", join("\n", @possible_links_out));
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
    return split("\n", _read_file($filename . "_CACHE_possible_links_out"));
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
    return split("\n", _read_file("$conf{CNF_CACHES_DIR}/linkable_pages"));
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
    
    $data = _read_file($filename) || qq~Nothing is in the page yet.  Click the "edit this page" link to add some text.~;

    my $remove_border = 1;

    # Unless an option has been set to *not* wrap the text, wrap it.
    if (! page_fopt($page_name, 'exists', "has_no_text_wrap")) {
        # gemhack 5 - The Text::Wrap module was patched by Gordon to remove
        # the unexpanding of tabs because it was buggy and we don't use tabs
        # in our textareas. [tag:patched]
        
        $data = join('', _wrap_text($data));
        
        # do not remove the border if it's wrapped, since the text will fit
        # inside of the border with no problems.
        $remove_border = 0; 
    }

    my $encoded_data = _encode_entities($data);

    $encoded_data =~ s/ /&nbsp;/g;

    $encoded_data =~ s/\n/<br>/g;

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

    if (! $resolved_alias) {
        my $no_opts_str = '';
        if ($no_opts) {
            $no_opts_str = "&nm_no_opts=1";
        }
        $edit = qq~<a id="myel_edit_link" href="./?PH_edit&nm_page=$page_name&nm_rev=$revision$no_opts_str" style="margin-right:40px;">edit this page</a>~;
        $advanced = qq~<a href="./?PH_page_opts&nm_page=$page_name" style="margin-right:100px;">advanced options</a>~;
    }
    else {
        $edit = qq~<span style="color:red;margin-right:20px;">this page is read only</span>~;
    }

    my $rss_feed_icon = qq~<a href="./?PH_rss&nm_pages=$page_name" style="float:right;">
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

    my $create_new_link = qq~<a href="./?PH_create" style="margin-right:40px;">create a new page</a>~;
    $create_new_link = '' if page_fopt($page_name, 'exists', "remove_create_new_link");

    my $blowfish_buttons = ($show_encryption_buttons) ? _blowfish_buttons("decrypt_only") : '';

    my $bar_color_hex = page_fopt($page_name, 'get', 'bar_color_hex') || 'eee';

    $body = qq~
        $rss_feed_icon
        <p style="margin-bottom:30px;background-color:#$bar_color_hex;">
            $edit
            $create_new_link
            $advanced
        </p>
        $revision_alert
        $blowfish_buttons
        <p id="myel_text" style="font-family:monospace;">$encoded_data</p>
        
    ~;

    hprint(
        $body,
        {   remove_border        => $remove_border,
            remove_branding      => $remove_branding,
            remove_container_div => $remove_container_div,
            page_name            => $page_name,
            add_keys_js          => 1,
            add_blowfish_js      => $show_encryption_buttons,
        }
    );

}

sub _get_alias_pages {
    return split("\n", _read_file("$conf{CNF_CACHES_DIR}/alias_pages"));
}

sub page_does_not_exist {
    my $page_name = shift;

    _slow_down_if_too_many_guesses();

    my $body = qq~
        <p style="color:red;">This page doesn't exist.</p>
        <a href="./?PH_create_submit&nm_page=$page_name">create it as a new page</a>

        <p>or</p>

        <a href="./?PH_help_find">help me find a page I already created</a>

    ~;

    hprint($body);

}

sub _clear_old_page_name_guesses {
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

sub _slow_down_if_too_many_guesses {
    # Subtly slow down the response if there are too many guesses from the
    # same IP address.  This is to try to avoid any kind of a brute force
    # attack from a single IP address.
    # [tag:security] [tag:hacking] [tag:hacker]

    _clear_old_page_name_guesses();

    my $ip_address_of_guess = $ENV{REMOTE_ADDR};

    $ip_address_of_guess =~ s/\./_/g;

    my $guess_file = "$conf{CNF_CACHES_DIR}/guess_$ip_address_of_guess";

    my $num_guesses = (-e $guess_file)
        ? _read_file($guess_file)
        : 0;

    $num_guesses++;

    _write_file($guess_file, $num_guesses);

    # allow for three wrong guesses before starting to affect performance.
    # gemhack 4 - will "idling" the Perl script negatively affect the web
    # server's ability to serve more requests?
    if ($num_guesses > 3) {
        sleep 2 * ($num_guesses - 3);
    }
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
    $f1 = _read_file($f1);
    $f2 = _read_file($f2);
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
        my $diff_text = _encode_entities($diff);

        $diff_text =~ s{\r\n}{<br>}g;
        $diff_text =~ s{\n}{<br>}g;
        $diff_text =~ s{'}{\\'}g;

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

sub PH_rss {
    require DateTime;

    my $page_names = shift;

    my $MAX_NUM_REVISIONS = 20;
    my $should_check_page_names = undef;

    if ($page_names) {
        # [tag:performance]
        # Called by the PH_page_links subroutine, which already has a
        # list of existing pages... so no need to re-check the page names,
        # which is slow.
        $should_check_page_names = 0;
    }
    else {
        # Called by a GET request.  Check the page names, since there may
        # have been misspellings in the URL.
        $page_names = $cgi->param("nm_pages");
        $should_check_page_names = 1;
    }

    my @pages = split(/-/, $page_names);

    # If you're looking at more than one page, show a prefix in
    # front of the revision number for the page.
    my $show_page_prefixes = (scalar(@pages) > 1) ? 1 : 0;

    if ($should_check_page_names) {
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

            $diff_text =~ s{\n}{<br>}g;

            $revision_ref->{days_old} = $days_old;
            $revision_ref->{page_name} = $page_name;
            $revision_ref->{revision_rss_time} = $this_revision_time_str;
            $revision_ref->{rss_item} = qq~
                 <item>
                  <title>${page_prefix}revision $rev</title>
                  
                  <link>http://$conf{CNF_SITE_BASE_URL}/?PH_show_page&amp;nm_page=$page_name&amp;nm_rev=$rev</link>
                  <pubDate>$this_revision_time_str</pubDate>
                  <guid>http://$conf{CNF_SITE_BASE_URL}/?PH_show_page&amp;nm_page=$page_name&amp;nm_rev=$rev</guid>
                  <description><![CDATA[$diff_text]]></description>
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
        hprint($body);
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
        <input id="myel_blowfish_key" type="text" value="some_key" />
    </div>
    ~;
}

sub PH_edit {
    my $page_name = $cgi->param("nm_page");
    my $revision = $cgi->param("nm_rev");
    my $no_opts = $cgi->param('nm_no_opts') || 0;

    my $error = _check_page_name_is_ok($page_name);
    throw($error) if $error ne 'ok';

    if (_is_page_alias_for($page_name)){
        my $error = qq~You can't edit this page~;
        throw($error) if $error ne 'ok';
    }

    my $text = '';

    my $filename = get_filename_for_revision($page_name, $revision);
    
    if (-e $filename) {
        $text = _read_file($filename) || "";
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
    # [tag:security] [tag:hacking] [tag:hacker]
    $text =~ s/textarea/text_area/gi;

    $text = _maybe_add_blog_heading($text);

    my $show_encryption_buttons = page_fopt($page_name, 'exists', "show_encryption_buttons");
    my $remove_branding = page_fopt($page_name, 'exists', "remove_branding");
    my $remove_container_div = page_fopt($page_name, 'exists', "remove_container_div");

    my $blowfish_buttons = ($show_encryption_buttons) ? _blowfish_buttons("both") : '';

    my $cancel_url = "./?PH_show_page&nm_page=$page_name&nm_rev=$revision$no_opts_uri";

    my $body = qq~
        $revision_alert
        $first_edit_alert
        <form id="fr_edit_page" method="post" action="./?$page_name">
            <input type="hidden" name="PH_page_submit" value="1">
            <input type="hidden" name="nm_page" value="$page_name">
            <input type="hidden" name="nm_no_opts" value="$no_opts">
            <input type="hidden" name="nm_head_revision_number_at_edit_start" value="$head_revision_number">

            <p style="color:#339">Use just plain text.  There's no fanciness here.</p>

            $blowfish_buttons

            <textarea id="myel_text_area" name="nm_text" cols="80" rows="22" style="font-size:12px;">$text</textarea>
            
            <div>
                <input type="submit" name="nm_submit" value="save" class="form" style="margin-right:10px;">
                <input type="button" value="cancel" class="form" onclick="document.location = '$cancel_url';">
            </div>
        </form>
    ~;

    hprint($body, {add_blowfish_js => $show_encryption_buttons, remove_branding => $remove_branding, remove_container_div => $remove_container_div});
}

sub _maybe_add_blog_heading {
    my $text = shift;
    my $is_blog = $cgi->param("nm_is_blog") || 0;
    return $text if ! $is_blog;


    #gemhack 5 - yucky yucky hack hack
    my $datetime = `date`;
    $datetime =~ s/(\d+):(\d+):\d+/$1:$2/;
    my $am_pm = ($1 >= 12) ? "pm" : "am";
    my $hour = ($1 > 12) ? $1 - 12 : $1;
    $datetime =~ s/PDT 2007/$am_pm/;
    $datetime =~ s/(\d+):(\d+)/$hour:$2/;

    return qq~-----------------------------------------------------------------------
$datetime

$text
~;

}

sub _fopts_params {
    my $page_name = shift;
    my $message = "";

    my %fopts = get_fopts();
    for my $fopt_name (sort keys %fopts) {

        my $param = $cgi->param("nm_" . $fopt_name);
        if ($param){
            if ($fopts{$fopt_name}->{is_boolean}) {
                my $action = ($param eq 'yes') ? 'create' : 'remove';
                page_fopt($page_name, $action, $fopt_name);
                $message = $fopts{$fopt_name}->{"${param}_message"};

                if ($fopt_name eq 'allows_incoming_links') {
                    _calculate_linkable_pages_cache();
                }
            }
            elsif ($fopts{$fopt_name}->{is_color}) {
                if ($param !~ m{[0-9a-fA-F]{3,6}}) {
                    throw("Must be a valid hexadecimal color without the prepended #");
                }
                else {
                    page_fopt($page_name, 'create', $fopt_name, $param);
                    $message = $fopts{$fopt_name}->{set_message};
                }
            }
        }
    }

    return $message;

}

sub _fopts_links {
    my $page_name = shift;
    my $url = shift;

    my %fopts = get_fopts();
    my %fopt_link_for = ();
    for my $fopt_name (sort keys %fopts) {

        my $level = $fopts{$fopt_name}->{level};
        my $url_base = qq~<a href="./?$url&nm_page=$page_name&nm_level=$level&nm_$fopt_name=~;
        if ($fopts{$fopt_name}->{is_boolean}) {
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
        ~;

#    for my $key (keys %fopt_link_for) {
#        $body .= "<p>$key : $fopt_link_for{$key}</p>";
#    }

    hprint($body, {stylesheet_only => 1});

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

    $text_for_level{more} = qq~
            <div style="margin-bottom:40px;"><strong>RSS feed</strong>
                <p style="margin-left:20px;margin-bottom:20px;"><a href="http://$conf{CNF_SITE_BASE_URL}/?PH_rss&nm_pages=$page_name">RSS feed of this page</a> (given as diffs between revisions)</p>
            </div>
            <div style="margin-bottom:40px;"><strong>Linking</strong>
                <p style="margin-left:20px;">$fopt_link_for{"has_linking"}</p>
                <p style="margin-left:20px;">$fopt_link_for{"allows_incoming_links"}</p>
            </div>

            <div style="margin-bottom:40px;"><strong>Text Wrapping</strong>
                <p style="margin-left:20px;">$fopt_link_for{"has_no_text_wrap"}</p>
            </div>

            <div style="margin-bottom:40px;"><strong>Notes about doing things faster</strong>
                <p style="margin-left:20px;">You can double click on the text to edit it.</p>
            </div>

            <p style="margin-top:30px;"><strong>Soon to come:</strong><p>
            <ul>
                <li>Creation of readonly page aliases</li>
            </ul>
        </div>
    ~;

    my $plain_text_url = "http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name";
    my $bar_color_hex = page_fopt($page_name, 'get', 'bar_color_hex') || 'eee';

    $text_for_level{very} = qq~
            <div style="margin-bottom:30px;"><strong>Keyboard Shortcuts</strong>
                <p style="margin-left:20px;">the 'w' key brings up some page options when viewing the text.</p>
            </div>

            <div style="margin-bottom:30px;"><strong>Multiple pages in a single RSS feed</strong>
                <p style="margin-left:20px;">Use a minus to delimit the pages.</p>
                <p style="margin-left:20px;">For example, for <span style="color:#448;margin-left:10px;margin-right:10px;">mom_birthday_2007</span> and <span style="color:#448;margin-left:10px;margin-right:10px;">meeting_notes_070305</span> you would say:</p>
                <p style="margin-left:20px;">http://$conf{CNF_SITE_BASE_URL}/?PH_rss&nm_pages=mom_birthday_2007-meeting_notes_070305</p>
            </div>
            
            <div style="margin-bottom:30px;"><strong>Plain text</strong> (not delivered in an html container) to facilitate easy page scraping:
                <p style="margin-left:20px;">the latest rev: <a href="http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name">http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name</a></p>
                <p style="margin-left:20px;">rev 2: <a href="http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name&nm_rev=2">http://$conf{CNF_SITE_BASE_URL}/?PH_plain&nm_page=$page_name&nm_rev=2</a></p>
            </div>

            <div style="margin-bottom:30px;"><strong>Page Data</strong>
                <p style="margin-left:20px;">Page as a .tgz file (includes all revisions and options)</p>
                <p style="margin-left:20px;">Click <a href="./?PH_pages_tgz&nm_pages=$page_name">here</a> to create the tgz file.</p>
            </div>

            <div style="margin-bottom:30px;"><strong>Page Links</strong>
                <p style="margin-left:20px;">(Subject To Change... will be part of link search)</p>
                <p style="margin-left:20px;"><a href="./?PH_page_links&nm_page=$page_name">show links</a></p>
            </div>

            <div style="margin-bottom:30px;">
                <!--[tag:security] [tag:privacy]-->
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

    hprint($body);
}

sub _calculate_linkable_pages_cache {
    # Calculate all the page names and cache them.
    my @pages = map( { s/_FOPT_allows_incoming_links$//; $_ } split(/\n/, `cd $conf{CNF_TEXTS_DIR}; ls *_FOPT_allows_incoming_links`) );
    my $linkable_pages = join("\n", sort(@pages));
    _write_file("$conf{CNF_CACHES_DIR}/linkable_pages", $linkable_pages);
}

sub _calculate_alias_pages_cache {
    # Calculate all the page names and cache them.
    my @pages = map( { s/_ALIAS$//; $_ } split(/\n/, `cd $conf{CNF_TEXTS_DIR}; ls *_ALIAS`) );
    my $alias_pages = join("\n", sort(@pages));
    _write_file("$conf{CNF_CACHES_DIR}/alias_pages", $alias_pages);
}

sub page_fopt {
    my $page_name = shift;
    my $get_create_or_remove = shift;
    my $opt = shift;
    my $value = shift || '';

    if (! _is_in_set($get_create_or_remove, qw(get create remove exists)) ) {
        throw("get_create_or_remove must be [get create remove exists] not $get_create_or_remove");
    }

    my %fopts = get_fopts();
    if (! _is_in_set($opt, sort keys %fopts) ) {
        throw("option $opt is not a valid page option");
    }

    my $filename = "$conf{CNF_TEXTS_DIR}/${page_name}_FOPT_$opt";

    if ($get_create_or_remove eq 'exists') {
        return 1 if -e $filename;
        return 0;
    }
    if ($get_create_or_remove eq 'get') {
        return '' if ! -e $filename;
        my $value = _read_file($filename, $value);
        return $value;
    }
    if ($get_create_or_remove eq 'create') {
        _write_file($filename, $value);
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
        is_boolean => 1,
        is_color => 0,
        yes_message =>
            "Any links to other pages will now be <strong>visible</strong>",
        no_message =>
            "Any links to other pages will now be <strong>hidden</strong>",
            no_link => "in the page's text, <strong>hide</strong> any links to other pages",
            yes_link => "in the page's text, <strong>show</strong> any links to other pages",
    },
    allows_incoming_links => {
        level => 'more',
        is_boolean => 1,
        is_color => 0,
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
        is_boolean => 1,
        is_color => 0,
        yes_message => "The encryption buttons are now <strong>shown</strong> on the page",
        no_message => "The encryption buttons are <strong>no longer</strong> shown on the page",
            no_link => "<strong>hide</strong> the encryption buttons",
            yes_link => "<strong>show</strong> the encryption buttons",
    },
    has_no_text_wrap => {
        level => 'more',
        is_boolean => 1,
        is_color => 0,
        yes_message =>
            "The text is <strong>no longer</strong> wrapped at 80 characters",
        no_message =>
            "The text has been <strong>wrapped</strong> at 80 characters",
            no_link => "<strong>wrap</strong> the text",
            yes_link => "<strong>unwrap</strong> the text",
    },
    remove_branding => {
        level => 'very',
        is_boolean => 1,
        is_color => 0,
        yes_message =>
            "The branding has been <strong>removed</strong> from the page",
        no_message =>
            "The branding is now <strong>showing</strong> on the page",
            no_link => "<strong>show</strong> the branding",
            yes_link => "<strong>remove</strong> the branding",
    },
    remove_create_new_link => {
        level => 'very',
        is_boolean => 1,
        is_color => 0,
        yes_message =>
            "The 'create new page' link has been <strong>removed</strong> from the page",
        no_message =>
            "The 'create new page' link is now <strong>showing</strong>",
            no_link => "<strong>show</strong> the 'create new page' link",
            yes_link => "<strong>remove</strong> the 'create new page' link",
    },
    remove_container_div => {
        level => 'very',
        is_boolean => 1,
        is_color => 0,
        yes_message =>
            "The container div has been <strong>removed</strong> from the page",
        no_message =>
            "The container div is now <strong>used</strong>",
            no_link => "<strong>use</strong> the container div",
            yes_link => "<strong>remove</strong> the container div",
    },
    bar_color_hex => {
        level => 'very',
        is_boolean => 0,
        is_color => 1,
        set_message => "The bar's color was set.",
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
        hprint($body);
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

    hprint($body);
}

sub PH_page_submit {
    my $page_name = $cgi->param("nm_page");
    my $text = $cgi->param("nm_text");
    my $head_revision_number_at_edit_start = $cgi->param("nm_head_revision_number_at_edit_start");
    my $no_opts = $cgi->param('nm_no_opts') || 0;

    my $no_opts_str = ($no_opts) ? "&nm_no_opts=1" : '';

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

    _write_new_page_revision($page_name, $text);

    if ($no_opts) {
        do_redirect("./?PH_show_page&nm_page=$page_name$no_opts_str");
    }
    else {
        do_redirect("./?$page_name");
    }

    #show_page($page_name);
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
    hprint($body);
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
    _write_file($filename . "_HEAD", $text);

    # Now write the revision file to the ${page_name}_REVS folder

    my $rev = get_page_HEAD_revision_number($page_name, 'cached') + 1;

    my $page_rev = "${page_name}_R$rev";

    my $revs_dir = "${filename}_REVS";
    mkdir($revs_dir) if (! -d $revs_dir);
    my $rev_filename = "$revs_dir/$page_rev";
    _write_file($rev_filename, $text);

    # Writing stuff to a backup directory is an extra precaution
    # against data loss.
    my $backup_dir = "$conf{CNF_TEXTS_BACKUP_DIR}";
    mkdir($backup_dir) if (! -d $backup_dir);
    my $time = time(); # The time adds a bit of randomness to the end
    _write_file("$backup_dir/${page_rev}_$time", $text);
    
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
        my $target_page_name = _read_file($alias_file);
        chomp($target_page_name);
        return $target_page_name;
    }

    return 0;
}

sub get_page_HEAD_revision_number {
    my $page_name = shift;
    my $real_or_cached = shift;

    if (! _is_in_set($real_or_cached, qw(real cached)) ) {
        throw("real_or_cached must be real or cached, not $real_or_cached");
    }

    if ($real_or_cached eq 'cached') {
        my $file = "$conf{CNF_TEXTS_DIR}/${page_name}_HREV";
        if (-e $file) {
            return _read_file("$conf{CNF_TEXTS_DIR}/${page_name}_HREV");
        }
        else {
            return -1;
        }
    }

    #gemhack 1 - If there are more than 10,000,000 revisions, this will fail.
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
    _write_file("$conf{CNF_TEXTS_DIR}/${page_name}_HREV", $revision);
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

    my $maybe_create_page_js = "";
    my $maybe_blowfish_js    = "";
    my $maybe_keys_js        = "";

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

        # [tag:compatibility]
        # gemhack 5 - If you change the following to be XMTML, it will fail
        # in Internet Explorer 7 for some odd reason.  Don't do it!
        my $do_not_change_formatting_of_script_include = qq~
            <script src="./static/blowfish.js" type="text/javascript"></script>
        ~;

        $maybe_blowfish_js = qq~
            <script type="text/javascript" language="javascript">
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

    my $maybe_keys_palette_div = "";
    if ($arg_ref->{add_keys_js}) {

        # [tag:compatibility]
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

    # The global message should go in the branding, so it doesn't show up
    # in embedded pages.
    my $global_message = qq~<span style="color:red">I screwed up and deleted all revisions of this page created between midnight and 9am PST. <a href="./screwup_more_info">more info</a></span><br><br>~;

    if ($arg_ref->{page_name}) {
        if (! _is_in_set($arg_ref->{page_name}, qw(testingbobcowmoof wikiclock cabinet weird_professional_identity_descriptions testingme))) {
            $global_message = "";
        }
    }
    else {
        $global_message = "";
    }
    $global_message = "";

    my $branding = qq~
        $global_message
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
   "http://www.w3.org/TR/html4/loose.dtd"><html><head><title>$conf{CNF_SITE_READABLE_NAME}</title>
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
        # [tag:performance] This looks somewhat obfuscated because
        # indenting takes up more bandwidth.
        filter_print(qq~$document_start
    $doubleclick_js
    $maybe_create_page_js
    $maybe_blowfish_js
    $maybe_keys_js
    </head>
    <body style="margin-left:10px;" onload="if(document.getElementById('myel_text_area')){document.getElementById('myel_text_area').focus()}">
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
# sect: IO
#-----------------------------------------------------------------------------

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

#-----------------------------------------------------------------------------
# sect: libraries
#-----------------------------------------------------------------------------

sub _compat_require_file_find {
    # [tag:compatibility] - we might want to allow for Win32 later,
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
