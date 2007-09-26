# run this test from the command line either directly with:
# perl Potoss.t, or
# prove Potoss.t if you have prove installed.  It comes with the
# Test::Harness module.

use strict;
use warnings;

use Test::More tests => 50;

# Since you're in the testing mode, make any "throws" die with a lot of info.
$ENV{POTOSS_THROW_DIES_WITH_MORE_INFO} = 1;

use lib qw(potoss_code);
chdir("../");
require Potoss;


#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("utilities");

my $result = Potoss::semiRandText(30);
is(length($result), 30, "produces right length output");

$result =~ /^([a-j]+)$/;
is(length($1), 30, "only contains a-j characters");


#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("exists");

ok(Potoss::_page_exists("potoss_test_link_tree_a_base"), "The page exists - part 1");
is(Potoss::_page_exists("non_existant_page_flsnalknow"), 0, "The page does not exist");
is(Potoss::_page_exists("fla slwo wofhne sosna "), 0, "The page does not exist (with spaces)");
is(Potoss::_page_exists('Hella &3#@9@!)@&#'), 0, "The page does not exist (with spaces and more junk)");
ok(Potoss::_page_exists("potoss_test_link_tree_a_branch_a_leaf_b"), "The page exists - part 2");

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("linking");

my @links;
my @page_names;
my @link_names_only;


@page_names = qw(
    potoss_test_link_tree_a_branch_a
    potoss_test_link_tree_a_branch_b
    potoss_test_link_tree_a_branch_c
    potoss_test_non_existent_page
    potoss_test_existing_but_not_linkable_to_page
);
@link_names_only = Potoss::page_read_text_and_calculate_all_possible_links("potoss_test_link_tree_a_base");
is_deeply(\@link_names_only, \@page_names, "base - all possible links");


@page_names = qw(
    potoss_test_link_tree_a_branch_a
    potoss_test_link_tree_a_branch_b
    potoss_test_link_tree_a_branch_c
);
@link_names_only = Potoss::page_read_text_and_calculate_only_valid_links("potoss_test_link_tree_a_base");
is_deeply(\@link_names_only, \@page_names, "base - only valid links");

@links = test_get_page_links("potoss_test_link_tree_a_base", {max_depth => 1, mode => 'real'});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "base - max_depth 1 - real");
is($links[0]{used_preexisting_cache}, 0, "Did NOT use a pre-existing cache");

ok(Potoss::_links_out_cache_file_create_or_update("potoss_test_link_tree_a_base"), "it was able to create the cache file");

@links = test_get_page_links("potoss_test_link_tree_a_base", {max_depth => 1, mode => 'cached'});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "base - max_depth 1 - cached (it is available)");
is($links[0]{used_preexisting_cache}, 1, "Used a pre-existing cache");

ok(Potoss::_links_out_cache_file_remove("potoss_test_link_tree_a_base"), "It was able to remove the cache file");

@links = test_get_page_links("potoss_test_link_tree_a_base", {max_depth => 1, mode => 'cached'});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "base - max_depth 1 - cached (it is NOT available)");
is($links[0]{used_preexisting_cache}, 0, "Did NOT use a pre-existing cache");


@page_names = qw(
    potoss_test_link_tree_a_branch_a_leaf_a
    potoss_test_link_tree_a_branch_a_leaf_b
);
@links = test_get_page_links("potoss_test_link_tree_a_branch_a", {max_depth => 1, mode => 'real'});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "branch a - max_depth 1");


@page_names = qw(
    potoss_test_link_tree_a_branch_a
    potoss_test_link_tree_a_branch_a_leaf_a
    potoss_test_link_tree_a_branch_a_leaf_b

    potoss_test_link_tree_a_branch_b
    potoss_test_link_tree_a_branch_b_branch_a
    potoss_test_link_tree_a_branch_b_branch_b
    potoss_test_link_tree_a_branch_b_leaf_a

    potoss_test_link_tree_a_branch_c
    potoss_test_link_tree_a_branch_c_leaf_a
    potoss_test_link_tree_a_branch_c_leaf_b
    potoss_test_link_tree_a_branch_c_leaf_c
    potoss_test_link_tree_a_branch_c_leaf_d
);
@links = test_get_page_links("potoss_test_link_tree_a_base", {max_depth => 2, mode => 'real'});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "base sorted- max_depth 2");


@page_names = qw(
    potoss_test_link_tree_a_branch_a
    potoss_test_link_tree_a_branch_a_leaf_a
    potoss_test_link_tree_a_branch_a_leaf_b

    potoss_test_link_tree_a_branch_b
    potoss_test_link_tree_a_branch_b_branch_a
    potoss_test_link_tree_a_branch_b_branch_b
    potoss_test_link_tree_a_branch_b_leaf_a

    potoss_test_link_tree_a_branch_c
    potoss_test_link_tree_a_branch_c_leaf_a
    potoss_test_link_tree_a_branch_c_leaf_b
    potoss_test_link_tree_a_branch_c_leaf_c
    potoss_test_link_tree_a_branch_c_leaf_d
);
@links = test_get_page_links("potoss_test_link_tree_a_base", {max_depth => 2, mode => 'real'});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "base sorted- max_depth 2 - real");

@links = test_get_page_links("potoss_test_link_tree_a_base", {max_depth => 2, mode => 'cached'});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "base sorted- max_depth 2 - cached (but not available)");

#-----------------------------------------------------------------------------
# Story: Prune one of the branches

@page_names = qw(
    potoss_test_link_tree_a_branch_b
    potoss_test_link_tree_a_branch_b_branch_a
    potoss_test_link_tree_a_branch_b_branch_b
    potoss_test_link_tree_a_branch_b_leaf_a

    potoss_test_link_tree_a_branch_c
    potoss_test_link_tree_a_branch_c_leaf_a
    potoss_test_link_tree_a_branch_c_leaf_b
    potoss_test_link_tree_a_branch_c_leaf_c
    potoss_test_link_tree_a_branch_c_leaf_d
);
@links = test_get_page_links("potoss_test_link_tree_a_base", {max_depth => 2, mode => 'real', prune_list => ['potoss_test_link_tree_a_branch_a']});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "Prune one of the branches");

# End Story
#-----------------------------------------------------------------------------
# Story: Prune a different branch

@page_names = qw(
     potoss_test_link_tree_a_branch_a
    potoss_test_link_tree_a_branch_a_leaf_a
    potoss_test_link_tree_a_branch_a_leaf_b

    potoss_test_link_tree_a_branch_c
    potoss_test_link_tree_a_branch_c_leaf_a
    potoss_test_link_tree_a_branch_c_leaf_b
    potoss_test_link_tree_a_branch_c_leaf_c
    potoss_test_link_tree_a_branch_c_leaf_d
);
@links = test_get_page_links("potoss_test_link_tree_a_base", {max_depth => 2, mode => 'real', prune_list => ['potoss_test_link_tree_a_branch_b']});
@link_names_only = link_names_only(@links);
is_deeply(\@link_names_only, \@page_names, "Prune a different branch");

# End Story
#-----------------------------------------------------------------------------

sub test_get_page_links {
    my $page_name = shift;
    my $arg_ref = shift;
    my @links = Potoss::page_get_links_out_recursive($page_name, [], $arg_ref);
    return @links;
}

sub link_names_only {
    my @links = @_;
    @links = sort {$a->{order} <=> $b->{order} } @links;
    @links = map({$_->{page_name}} @links);
    return @links;
}

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("page naming");

is(Potoss::_is_in_dictionary("blow"), "blow", "blow in dictionary");
is(Potoss::_is_in_dictionary("John"), 'John', "John in dictionary");

is(Potoss::_is_in_dictionary("hakwifhn"), '', "hakwifhn not in dictionary");
is(Potoss::_is_in_dictionary("blahowond"), '', "blahowond not in dictionary");

like(
    Potoss::_check_page_name_is_ok(
        "adlkjdfoiwaejkmlasliejaiojnakdfandknwoiekasdnflkasdfknaiwoein"),
    qr{Seriously\?},
    "_really_ long page_name"
);

like(
    Potoss::_check_page_name_is_ok(
        "adl"),
    qr{should be at least},
    "short page_name"
);

like(
    Potoss::_check_page_name_is_ok(
        "pumpkin"),
    qr{is in the dictionary},
    "is in the dictionary"
);

is(
    Potoss::_check_page_name_is_ok(
        "pumpkin_flow_is_very_cool"),
    'ok',
    "the page name is ok"
);

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("normalization of the page name");

is( Potoss::normalize_page_name("Rotten Tomatoes"), "rotten_tomatoes", "rotten_tomatoes");
is( Potoss::normalize_page_name("GReen  Lawn"), "green__lawn", "green__lawn");
is( Potoss::normalize_page_name("Hot-and-heavy!!!"), "hot_and_heavy", "hot_and_heavy");
is( Potoss::normalize_page_name("this_name_should_be_the_same"), "this_name_should_be_the_same", "this_name_should_be_the_same");

is( Potoss::get_page_HEAD_revision_number( "potoss_saved_test", 'cached' ),
    "11", "on version 11 cached" );
is( Potoss::get_page_HEAD_revision_number( "potoss_saved_test", 'real' ),
    "11", "on version 11 real" );

is( Potoss::_test_num_pages(qr{potoss_saved}),
    1, "There is one page which matches potoss_saved" );

#Create and delete a page and test that.
my $page_name = "usn_lkd_nslanf_sb_alk";

is( Potoss::_test_num_pages(qr{$page_name}),
    0, "No pages match rand string - part 1" );
Potoss::_write_new_page_revision( $page_name, "some text" );
is( Potoss::_test_num_pages(qr{$page_name}),
    1, "One page matches rand string" );

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("file options (fopts)");

is( Potoss::page_fopt( $page_name, 'exists', "has_linking" ),
    0, "does not have linking - first time" );
Potoss::page_fopt( $page_name, "create", "has_linking" );
is( Potoss::page_fopt( $page_name, 'exists', "has_linking" ),
    1, "now has linking" );
Potoss::page_fopt( $page_name, "remove", "has_linking" );
is( Potoss::page_fopt( $page_name, 'exists', "has_linking" ),
    0, "does not have linking - again" );

is( Potoss::page_fopt( $page_name, 'exists', "show_encryption_buttons" ),
    0, "does not show_encryption_buttons" );
Potoss::page_fopt( $page_name, "create", "show_encryption_buttons" );
is( Potoss::page_fopt( $page_name, 'exists', "show_encryption_buttons" ),
    1, "now has show_encryption_buttons" );

is( Potoss::_test_num_fopts(qr{$page_name}),
    1, "There is one fopt for show_encryption_buttons" );

Potoss::_test_delete_page($page_name);

is( Potoss::_test_num_fopts(qr{$page_name}),
    0,
    "There are no fopts for the page now, since they've all been deleted" );

is( Potoss::_test_num_pages(qr{$page_name}),
    0, "No pages match rand string - part 2" );

Potoss::_tgz_pages("tar_potoss_single_page", "potoss_saved_test");
Potoss::_tgz_pages("tar_potoss_multiple_pages", qw(potoss_test_link_tree_a_branch_a potoss_test_link_tree_a_branch_b potoss_test_link_tree_a_branch_c));

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("page name guesses");

# Similate writing an older file so that it gets cleared by the
# _clear_old_guess_ip_addresses subroutine.
my $older_file = "$Potoss::conf{CNF_CACHES_DIR}/guess_12_34_56_78";
Potoss::_write_file($older_file, '3');

# Make it look two minutes old.
my $older_time = time() - 120;
utime($older_time, $older_time, $older_file);

my $newer_file = "$Potoss::conf{CNF_CACHES_DIR}/guess_90_12_34_56";
Potoss::_write_file($newer_file, '3');

my @guesses_cleared = Potoss::_clear_old_guess_ip_addresses();
ok( grep( {/guess_12_34_56_78/} @guesses_cleared ),
    "clears the older 12_34_56_78 guess"
);
ok( !grep( {/guess_90_12_34_56/} @guesses_cleared ),
    "does not clear the newer 90_12_34_56 guess"
);

unlink($newer_file);