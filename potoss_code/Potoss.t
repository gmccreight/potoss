# run this test from the command line either directly with:
# perl Potoss.t, or
# prove Potoss.t if you have prove installed.  It comes with the
# Test::Harness module.

use strict;
use warnings;

use Test::More tests => 32;

use lib qw(potoss_code);
chdir("../");
require Potoss;

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("linking");

my @links;
my @page_names;
@links = Potoss::page_get_links("potoss_test_link_tree_a_base", {}, {max_depth => 1, mode => 'real', sorted => 1});
is_deeply(\@links, [qw(potoss_test_link_tree_a_branch_a potoss_test_link_tree_a_branch_b potoss_test_link_tree_a_branch_c)], "base - max_depth 1");

@links = Potoss::page_get_links("potoss_test_link_tree_a_branch_a", {}, {max_depth => 1, mode => 'real', sorted => 1});
is_deeply(\@links, [qw(potoss_test_link_tree_a_branch_a_leaf_a potoss_test_link_tree_a_branch_a_leaf_b)], "branch a - max_depth 1");

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

@links = Potoss::page_get_links("potoss_test_link_tree_a_base", {}, {max_depth => 2, mode => 'real', sorted => 1});
is_deeply(\@links, \@page_names, "base sorted- max_depth 2");

@page_names = qw(
    potoss_test_link_tree_a_branch_a
    potoss_test_link_tree_a_branch_a_leaf_a
    potoss_test_link_tree_a_branch_a_leaf_b

    potoss_test_link_tree_a_branch_b
    potoss_test_link_tree_a_branch_b_branch_a
    potoss_test_link_tree_a_branch_b_branch_a_leaf_a
    potoss_test_link_tree_a_branch_b_branch_b
    potoss_test_link_tree_a_branch_b_branch_b_leaf_a
    potoss_test_link_tree_a_branch_b_leaf_a

    potoss_test_link_tree_a_branch_c
    potoss_test_link_tree_a_branch_c_leaf_a
    potoss_test_link_tree_a_branch_c_leaf_b
    potoss_test_link_tree_a_branch_c_leaf_c
    potoss_test_link_tree_a_branch_c_leaf_d
);

# potoss_test_link_tree_a_branch_b_branch_b
# has a circular reference, and a reference to the base, neither of which
# should show up.

@links = Potoss::page_get_links("potoss_test_link_tree_a_base", {}, {max_depth => 3, mode => 'real', sorted => 1});
is_deeply(\@links, \@page_names, "base sorted- max_depth 3");

@links = Potoss::page_get_links("potoss_test_link_tree_a_base", {}, {max_depth => 100, mode => 'real', sorted => 1});
is_deeply(\@links, \@page_names, "max_depth => 100 should give same result");



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

Potoss::_tgz_a_page("potoss_saved_test");

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
diag("page name guesses");

# Similate writing an older file so that it gets cleared by the
# _clear_old_page_name_guesses subroutine.
my $older_file = "$Potoss::conf{CNF_CACHES_DIR}/guess_12_34_56_78";
Potoss::_write_file($older_file, '3');
my $older_time = time() - 100;
utime($older_time, $older_time, $older_file);

my $new_file = "$Potoss::conf{CNF_CACHES_DIR}/guess_90_12_34_56";
Potoss::_write_file($new_file, '3');

my @guesses = Potoss::_clear_old_page_name_guesses();
ok( grep( {/guess_12_34_56_78/} @guesses ),
    "clears the older 12_34_56_78 guess"
);
ok( !grep( {/guess_90_12_34_56/} @guesses ),
    "does not clear the newer 90_12_34_56 guess"
);

unlink($new_file);