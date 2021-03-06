package PotConf;

use strict;
use warnings;

# gemhack 4 - We use a patched version of Text::Wrap, which is in the
# following directory: [tag:patched:gem]
use lib qw( ./potoss_code/patched_libs );

# [tag:easy_install:gem]
# Don't make the person install all the needed modules.  Give them default
# ones which work OK.
# Push this directory onto the end, so it's the last one that is checked.
# It's the fallback if you don't have the modules already installed on
# your system.  If you do, your system will use those.
# You can decide not to use this fallback library by simply commenting it out.

BEGIN { push(@INC, qw(./potoss_code/fallback_libs)); }

our %conf = ();

$conf{CNF_USE_COLONS_IN_URL} = 1;

$conf{CNF_SITE_READABLE_NAME} = 'page of text open source software . com';
$conf{CNF_SITE_BASE_URL} = 'www.potosssite.com';

$conf{CNF_DEFAULT_PAGE_FORMAT} = 'text'; #text or creole

$conf{CNF_DEFAULT_EMPTY_PAGE_MESSAGE} =
    qq~
    Nothing is in the page yet.
    Click the "edit this page" link to add some text.
    ~; 

$conf{CNF_NEW_PAGE_MESSAGE} = qq~
    <div style="background-color:#fee;">
        <p>Congratulations, you've created a new page!</p>
        <p>You should <strong>bookmark this page</strong> so you don't forget its URL.</p>
    </div>
~;

$conf{CNF_STYLE_SHEET} = './static/style.css';
$conf{CNF_ROOT_DIR} = '.';
$conf{CNF_DATA_DIR} = $conf{CNF_ROOT_DIR} . '/potoss_data';
$conf{CNF_TEXTS_DIR} = $conf{CNF_DATA_DIR} . '/texts_8s73f9dv';
$conf{CNF_TEXTS_BACKUP_DIR} = $conf{CNF_DATA_DIR} . '/texts_backup_v4c67';
$conf{CNF_CACHES_DIR} = $conf{CNF_DATA_DIR} . '/caches_9e3n6chh';

$conf{CNF_ADMIN_HE_OR_SHE} = 'he';
$conf{CNF_ADMIN_FIRST_NAME} = 'Homer';
$conf{CNF_ADMIN_FULL_NAME} = 'Homer Simpson';
$conf{CNF_ADMIN_EMAIL} = 'setme@example.com';

$conf{CNF_HTTP_SERVER_PORT} = 4782;

# Both of these look real, but they are just examples... you need to put your real ones in.
$conf{CNF_RECAPTCHA_PUBLIC_KEY} = "FakeDefaultValue";
$conf{CNF_RECAPTCHA_PRIVATE_KEY} = "FakeDefaultValue";

# Normally you need to fill in a reCAPTCHA just to turn reCAPTCHA on for a
# page.  If you're the site's administrator, that could be a bit of a pain,
# particularly if you're fighting a determined spammer.  Here we specify a code
# that allows the site admin (who knows the code) to turn reCAPTCHA on in an
# automated way.
$conf{CNF_RECAPTCHA_TURN_ON_CODE} = "jdwjd5";

# If you want the URL to be super easy, like www.potosssite.com/page_name
# then you'll need to set up mod_rewrite in Apache.  Once you've done that
# you can set this directive to 1, which will strip all the question marks
# out of the URLs so that they are even more legible.  See the Apache
# configuration below, which includes the "Rewrite" section.
$conf{CNF_SHOULD_STRIP_QUESTION_MARKS} = 0;

# If there is a Local file, any settings it contains supercede the settings in this file.
# We use the Local file to store our *real* RECAPTCHA configuration variables, since we
# don't want to share them as part of the open source code.
# Here is an example of what you might put in the local file:
# <SNIP>
# package PotConfLocal;
#
# use strict;
# use warnings;
#
# $PotConf::conf{CNF_RECAPTCHA_PUBLIC_KEY} =  "AAAG912dX-DEstCDJGPq";
# $PotConf::conf{CNF_RECAPTCHA_PRIVATE_KEY} = "AAAClTn-reAy6JMOiBpf";
#
# 1;
# </SNIP>

if (-e "./potoss_code/PotConfLocal.pm") {
    require PotConfLocal;
}

#<VirtualHost *:80>
#    DocumentRoot /var/potosssite
#    ServerAdmin setme@example.com
#    ServerName www.potosssite.com
#    ServerAlias potosssite.com *.potosssite.com
#    ErrorLog /var/log/apache2/potosssite.com-error_log
#    CustomLog /var/log/apache2/potosssite.com-access_log common

#    <Directory /var/potosssite>

#       RewriteEngine on
#       RewriteRule ^([A-Za-z_0-9&=\\:-]+)$ index.cgi?$1
#
#	    <FilesMatch "\.cgi$">
#            Options +ExecCGI
#            SetHandler cgi-script
#    	</FilesMatch>
#
#       DirectoryIndex index.cgi
#
#       Options FollowSymLinks
#	    Order allow,deny
#	    Allow from all
#
#    </Directory>
#
#</VirtualHost>

#### Config File Validation

for my $k (sort {length($conf{$a}) <=> length($conf{$b})}
           keys %conf) {
    next unless $k =~ m/DIR$/;
    my $dir = $conf{$k};
    next if -d $dir;
    die "Config directory $k doesn't exist at $dir!\n";
}

if ($conf{CNF_DEFAULT_PAGE_FORMAT} ne 'text'
    && $conf{CNF_DEFAULT_PAGE_FORMAT} ne 'creole') {
    die "Config: Default page format must be text or creole";
}

1;
