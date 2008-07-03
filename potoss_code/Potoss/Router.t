use strict;
use warnings;

use lib qw(..);
use Test::More tests => 8;
require Potoss::Router;

my $router = Potoss::Router->new();
$router->set_from_string("some_page_name:edit");
is($router->get_page(), "some_page_name");
is($router->get_action(), "PH_edit", "the first edit alias works");

$router->set_from_string("yellow_page_name:e");
is($router->get_page(), "yellow_page_name");
is($router->get_action(), "PH_edit", "the other edit alias works");

$router->set_from_string("green_page_name:rss");
is($router->get_page(), "green_page_name");
is($router->get_action(), "PH_choose_rss");

$router->set_from_string("other_page_name:options");
is($router->get_page(), "other_page_name");
is($router->get_action(), "PH_page_opts");

$router->set_from_string("other_page_name:opts");
is($router->get_page(), "other_page_name");
is($router->get_action(), "PH_page_opts");