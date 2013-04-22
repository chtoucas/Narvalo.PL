package Mail::Pine::Pinerc::Option;

use strict;
use warnings;

use base qw(Mail::Pine);

my %_multivalued;
# As of init.c version 4.790
@_multivalued{ qw(
    address-book
    addressbook-formats
    alt-addresses
    customized-hdrs
    default-composer-hdrs
    disable-these-authenticators
    disable-these-drivers
    display-filters
    editor
    feature-list
    folder-collections
    forced-abook-entry
    global-address-book
    incoming-archive-folders
    incoming-folders
    initial-keystroke-list
    keyword-colors
    keywords
    ldap-servers
    news-collections
    nntp-server
    patterns
    patterns-filters
    patterns-filters2
    patterns-indexcolors
    patterns-other
    patterns-roles
    patterns-scores
    patterns-scores2
    personal-print-command
    pruned-folders
    sending-filters
    smtp-server
    standard-printer
    stay-open-folders
    url-viewers
    viewer-hdr-colors
    viewer-hdrs
    )} = ();

sub new {
    bless \scalar '', $_[0];
}

sub is_multivalued {
    return exists $_multivalued{ ref($_[0]) ? ${$_[0]} : $_[0] };
}

1;
