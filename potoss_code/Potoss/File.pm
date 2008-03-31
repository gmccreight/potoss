package Potoss::File;

use strict;
use warnings;

sub read_file {
    # [tag:easy_install] - We don't use File::Slurp to avoid prerequisites
    my $filename = shift;
    open(my $fh, "<", $filename)
        || die "Cannot read from file $filename - $!";
    my @lines = <$fh>;
    close($fh)
        || die "could not close $filename after reading";
    return join("", @lines);
}

sub write_file {
    # [tag:easy_install] - We don't use File::Slurp to avoid prerequisites
    my $filename = shift;
    my $data = shift;
    open(my $fh, ">", $filename)
        || die "Cannot write to file $filename - $!";
    print $fh $data;
    close($fh)
        || die "could not close $filename after writing";
}

1;
