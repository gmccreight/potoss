package PotossTestingShared;

# Note: could be used in the Potoss.t file like this:
#require PotossTestingShared;
#PotossTestingShared::load_test_texts('a');
#$Potoss::conf{CNF_TEXTS_DIR} = $Potoss::conf{CNF_DATA_DIR} . '/texts_tests_a_tmp';
#die "The CNF_TEXTS_DIR is not a directory" if ! -d $Potoss::conf{CNF_TEXTS_DIR};

# Why is this unfinished?
# It works well from the Potoss.t file, but from Selenium tests, you'd have
# to come up with a way of letting the server know which database to use.
# This would require either a cookie or changing the URL of links, both of
# which add to complication, rather than subtract from it.

use strict;
use warnings;

require PotConf;

no warnings;
# Share the configuration
our %conf = %PotConf::conf;
use warnings;

sub load_test_texts {
    my $test_letter = shift;
    _sanity_check($test_letter);

    my $source_dir = "$conf{CNF_DATA_DIR}/texts_tests_$test_letter";
    my $dest_dir = _get_tmp_dir($test_letter);

    `rm -rf $dest_dir` if -d $dest_dir;

    die "source dir $source_dir does not exist" if ! -d $source_dir;
    `cp -a $source_dir $dest_dir`;
}

sub remove_test_texts {
    my $test_letter = shift;
    _sanity_check($test_letter);

    my $tmp_texts_dir = _get_tmp_dir($test_letter);

    die "tmp_texts_dir $tmp_texts_dir does not exist" if ! -d $tmp_texts_dir;
    `rm -rf $tmp_texts_dir`;
}

sub _get_tmp_dir {
    my $test_letter = shift;
    _sanity_check($test_letter);

    my $tmp_texts_dir = "$conf{CNF_DATA_DIR}/texts_tests_${test_letter}_tmp";
    return $tmp_texts_dir;
}

sub _sanity_check {
    my $test_letter = shift;
    die "test letter must be a-z" if ! $test_letter =~ m{^[a-z]$};
    die "the data dir $conf{CNF_DATA_DIR} must exist" if ! -d $conf{CNF_DATA_DIR};
}

1;
