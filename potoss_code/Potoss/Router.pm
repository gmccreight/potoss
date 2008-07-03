package Potoss::Router;

# The router takes a colon delimited string and turns it into several 
# parameters.  This has the effect of making easy to read URLs for
# some of the easier operations.  It also maintains backwards compatibility
# with the pre-existing URLs by mapping the new colon-delimited URL to the
# pre-existing paramters

use strict;
use warnings;

sub new {
    my $invocant = shift;
    my $self = bless({}, ref($invocant) || $invocant);
    $self->reset_data();
    return $self;
}

sub reset_data {
    my $self = shift;
    $self->{action} = "";
    $self->{page} = "";
}

sub set_from_string {
    my $self = shift;
    my $string = shift;

    my %route_for = (
        options =>
            { may_follow => qw(page), param => "PH_page_opts" },
        opts =>
            { may_follow => qw(page), param => "PH_page_opts" },
        create =>
            { may_follow => qw(page), param => "PH_create_from_page" },
        edit =>
            { may_follow => qw(page), param => "PH_edit" },
        e =>
            { may_follow => qw(page), param => "PH_edit" },
        rss =>
            { may_follow => qw(page), param => "PH_choose_rss" },
    );

    my @routes = split(/:/, $string);

    if ( scalar(@routes) > 1 ) {

        $self->{page} = $routes[0];
        my $action = $routes[1];

        $action = (exists $route_for{$action}->{param} )
            ? $route_for{$action}->{param}
            : $action;

        $self->{action} = $action;
        
        return 1;
    }
    else {
        return 0;
    }
}

sub get_action {
    my $self = shift;
    return $self->{action};
}

sub get_page {
    my $self = shift;
    return $self->{page};
}

1;
