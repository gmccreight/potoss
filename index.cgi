#!/usr/bin/perl

use strict;
use warnings;

use lib qw(potoss_code);

# The bulk of the work is done in the Potoss package.
require Potoss;
Potoss::main();