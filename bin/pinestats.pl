#!/usr/local/bin/perl -w

=head1 NAME

pinestats.pl - Stats mailboxes in your Pine Collection

=head1 SYNOPSIS

B<pinestats.pl> [options]

=head1 DESCRIPTION

B<pinestats.pl> is a command-line script that prints the number
of unread mails in mailboxes of your Pine Collection.

=cut

## TODO
# - broken CLI
# - better error reporting
# - use YAML


#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

use strict;
use warnings;

#use Readonly;
use File::Spec::Functions   qw(catfile);
use Getopt::Std             qw(getopts);
use Tie::IxHash;
use Storable                qw(retrieve store);

### Constants, sort of

#Readonly my $INBOXES => 'Inboxes';
our $INBOXES = 'Inboxes';

### Main

MAIN: {
    ### CLI options
    my %opts;
    getopts('hp:P:c:d:eavq', \%opts);
    if ($opts{h}) {
        help() and exit;
    }
    $opts{p} ||= catfile($ENV{HOME}, q[.pinestatsrc]);
    $opts{e} = 0 if $opts{e} && $opts{a};

    ### Selection rules extracted from pinestatsrc
    my %rules = %{ rules($opts{p}) };

    ### Map folder aliases found in pinerc to real paths
    my %folders;
    tie %folders, "Tie::IxHash";
    %folders = %{ folders($opts{P}) };

    ### Cache negotiation
    my $cache = $opts{p} . '.db';
    if ($opts{c}) {
        clean_cache($cache, %folders, $opts{c}) and exit;
    }
    elsif ($opts{d}) {
        dump_cache($cache, $opts{d}) and exit;
    }
    my %caches = %{ retrieve($cache) } if -e $cache;
    my $update = 0;

    ### Traverse the tree
    my %tree;
    tie %tree, "Tie::IxHash";
    %tree = %{ tree(\%folders, \%rules, $opts{e}, $opts{a}) };
    my($count, $summary) = stat_tree(\%tree, \%caches, $opts{q}, $opts{v});

    while (my($folder, $mboxes) = each %tree) {
        my @mboxes = sort @$mboxes;
        my($folder_count, $folder_summary) = stat_folder($folder, $opts{q});
        my $folder_path = $folder eq $INBOXES ? q{} : $folders{$folder};
        foreach (@mboxes) {
            my($mbox_count, $mbox_summary) = stat_mbox(
                catfile($folder_path, $_),
                $folder,
                $_,
                \%caches,
                \$update,
                $opts{q}
            );
            &$mbox_count();
            &$mbox_summary($folder_count);
        }
        &$folder_summary($count);
    }
    &$summary();

    ### Store cache on disk
    END {
        if ($update) {
            print "Finishing...\n";
            store \%caches, $cache;
        }
    }
}


#-------------------------------------------------------------------------------
# Subs
#-------------------------------------------------------------------------------

# Print script version and a bit of help
sub help {
    print << "HELP;";

This is pinestats.pl

Usage: pinestats.pl [options]

Options:
    -h              Print this help and exit
    -p <path>       Path to pinestats configuration file
    -P <path>       Path to Pine configuration file
    -e              Print stats on normaly hidden mboxes
    -a              Print stats on all mboxes
    -v              Verbose output
    -q              Only print the overall number of unread mails
    -d <level>      Dump cache datas

See man page for more help.

HELP;
    1;
}

# Parse pinestats configuration file
# Parameters:
#   (string)
# >> (hashref)
sub rules {
    my %rules;
    @rules{ qw(inboxes includes excludes blackholes) } = ();
    open my $pinestatsrc, '<', $_[0] or return \%rules;
    while (<$pinestatsrc>) {
        next if index($_, '#') == 0;        # Bypass comments
        chomp;
        s/\s+$//;                        # Remove trailing whitespaces
        s/^\s+//;                        # Remove leading whitespaces
        next unless length;
        my($key, $val) = split /=/, $_, 2;
        # Don't overwrite with empty values!
        next unless length $val;
        # For 'inboxes', we must pay attention to the tilde shortcut
        $val =~ s{^~([^/]*)}{ $1 ? (getpwnam($1))[7] : $ENV{HOME} }e
            if $key eq 'inboxes';
        $rules{$key} = $val;
    }
    close $pinestatsrc or warn "Can't close $_[0]: $!\n";
    return \%rules;
}

# Get paths to folders from aliases
# Parameters:
#   (string)
# >> (hashref)
sub folders {
    my %folders;
    tie %folders, "Tie::IxHash";

    my @collection = @{ _collection($_[0]) };

    foreach (@collection) {
        m{^"?([^"]*)"?\s"?([^"]*)"?$};
        my($nickname, $path) = ($1, $2);
        # Remote folder are ignored
        next if index($_, '{') == 0;
        # Delete last three characters '/[]'
        substr($path, -3) = '';
        # Replace tilde shortcut in path
        $path =~ s{^~([^/]*)}{ $1 ? (getpwnam($1))[7] : $ENV{HOME} }e;
        $folders{$nickname} = $path;
    }

    return \%folders;
}

# Build the tree of mboxes
# Parameters:
#   (hashref)
#   (hashref)
#   (string)
#   (string)
# >> (hashref)
sub tree {
    my($_folders_, $_rules_, $_exc_, $_all_) = @_;
    my %tree;
    tie %tree, "Tie::IxHash";

    my @folders    = keys %$_folders_;
    my %includes   = %{ _tree(\@folders, $_rules_->{includes}) };
    my %blackholes = %{ _tree(\@folders, $_rules_->{blackholes}) };
    my %excludes   = %{ _tree(\@folders, $_rules_->{excludes}) }
        unless $_all_;

    ### Chasing inboxes

    if (!$_exc_ and defined $_rules_->{inboxes}) {
        my @inboxes = _split($_rules_->{inboxes});
        $_ =~ s{ ^~([^/]*) }{ $1 ? (getpwnam($1))[7] : $ENV{HOME} }xe
            foreach @inboxes;
        @{ $tree{$INBOXES} } = @inboxes;
    }

    ### Traverse the tree

    my $full;        # Mark folder to be fully parsed
    my $path;        # Path to folder

  FOLDER:
    foreach my $dir (@folders) {
        if (%includes) {
            # Bypass a folder not listed in %includes
            next FOLDER if not exists $includes{$dir};
            # Stat all mboxes in $dir?
            $full = !%{ $includes{$dir} };
        }
        else {
            # Bypass all mboxes in a fully blackholed folder
            next FOLDER if exists $blackholes{$dir} and !%{ $blackholes{$dir} };

            unless ($_exc_) {
                # Bypass all mboxes in a fully hidden folder
                next FOLDER if exists $excludes{$dir} and !%{ $excludes{$dir} };
            }
            else {
                # Stat normaly hidden folders

                # Bypass a folder not listed in %excludes
                next FOLDER unless exists $excludes{$dir};
                # Stat all mboxes in $dir?
                $full = !%{ $excludes{$dir} };
            }
        }

        $path = $_folders_->{$dir};
        eval {
            opendir(DIR, $path) or die "$!";
        };
        if ($@) {
            warn "Can't open $dir: $@";
            next FOLDER;
        }

      MBOX:
        while (defined(my $mbox = readdir(DIR))) {
            # Only keep text files not starting with a dot
            next MBOX
                unless -T catfile($path, $mbox) and index($mbox, '.') != 0;
            if (%includes) {
                # Keep all or a subset of mboxes in $dir
                next MBOX unless $full or exists $includes{$dir}{$mbox};
            }
            else {
                # Bypass a blackholed mbox
                next MBOX if exists $blackholes{$dir}{$mbox};

                unless ($_exc_) {
                    # Bypass an excluded mbox
                    next MBOX if exists $excludes{$dir}{$mbox};
                }
                else {
                    # Keep all or a subset of mboxes in $dir
                    next MBOX unless $full or exists $excludes{$dir}{$mbox};
                }
            }
            push @{ $tree{$dir} }, $mbox;
        }

        closedir(DIR) or warn "Can't close $dir: $!\n";
    }

    return \%tree;
}

# Count messages in all mboxes
# Parameters:
#   (hashref)
#   (hashref)
#   (string)
#   (string)
# >> (array)
sub stat_tree {
    my($_tree_, $_caches_, $_quiet_, $_verb_) = @_;

    my $new = 0;
    my $all = 0;

    ### Count closure
    my $count = sub {
        $new += $_[0];                # Add count of new messages in the folder
        $all += $_[1];                # Add count of all messages in the folder
    };

    ### Summary closure
    my $summary = sub {
        print "Summary\n\tYou have $all mail(s)\n\t" unless $_quiet_;
        if ($new) {
            print "You have $new unread mail(s)\n";
            if ($_verb_) {
                my %senders;
                while (my($folder, $mboxes) = each %$_tree_) {
                    foreach (@$mboxes) {
                        while (
                            my($name, $count)
                                = each %{ $_caches_->{WHO}{$folder}{$_} }
                        ) {
                            $senders{$name} += $count;
                        }
                    }
                }
                print "Details\n" if %senders;
                print "\t($senders{$_}) $_\n" foreach keys %senders
            }
        }
        else {
            print "No unread mail\n";
        }
    };

    return($count, $summary);
}

# Count messages in a given folder
# Parameters:
#   (string)
#   (string)
# >> (array)
sub stat_folder {
    my($_folder_, $_quiet_) = @_;
    my $new = 0;
    my $all = 0;
    print "$_folder_\n" unless $_quiet_;

    ### Count closure
    my $count = sub {
        $new += $_[0];                # Count of new messages in the mbox
        $all += $_[1];                # Count of all messages in the mbox
    };

    ### Summary closure
    my $summary = sub {
        my($_all_count_) = @_;
        print "\tTotal:\t$all\n" unless $_quiet_;
        &$_all_count_($new, $all);
    };

    return($count, $summary);
}

# Count messages in a given mbox
# >> (array)
sub stat_mbox {
    my($_path_, $_folder_, $_mbox_, $_caches_, $_update_, $_quiet_) = @_;
    my $new = 0;        # Counter for new messages
    my $all = 0;        # Counter for all messages
    my $bug = 0;        # Counter for buggy messages

    ### Cache
    my $caches = $_caches_->{COUNT}{$_folder_}{$_mbox_};
    # Is it safe to use the cached values?
    # - We already came across this mbox
    # - The mbox has not been updated since last run
    my $use_cache
        = $caches->{TIMESTAMP}
          && ( stat($_path_) )[9] < $caches->{TIMESTAMP} ? 1
        :                                                  0
        ;
    my %whos unless $use_cache;            # Counters for senders
    unless ($use_cache) {
        $$_update_ ||= 1;
        # Load extra modules to easily parse email addresses
        require Email::Address;         # RFC 2822
        require MIME::Words;            # RFC 1522
        MIME::Words->import('decode_mimewords');
    }

    ### Count closure
    my $count = sub {
        if ($use_cache) {
            $all = $caches->{ALL};
            $new = $caches->{NEW};
            $bug = $caches->{BUG};
            return 1;
        }

        ## Parse the mbox
        my $in_head = 0;    # True inside message headers
        my $is_old  = 0;    # True for an old message
        my $is_del  = 0;    # True for a deleted message
        my $name    = q{};   # Sender name
                            # Must be reset in case there is no "From: " line
        my $from;
        my $mbox;
        eval {
            open $mbox, '<', $_path_ or die "$!";
        };
        if ($@) {
            warn "Can't open $_path_: $@";
            return;
        }

      LINE:
        while (<$mbox>) {
            if (index($_, 'From ') == 0 && !$in_head) {
                # Enter headers
                $all++;
                $in_head = 1;
                $is_old  = 0;
                $is_del  = 0;
                $name    = q{};
                next LINE;
            }

            next LINE unless $in_head;

          SWITCH: {
            index($_, 'From: ') == 0
                # From line if we need to keep track of user name
                && do {
                    $from = decode_mimewords(substr($_, 6));
                    # Oops! It's the invisible man
                    next LINE unless $from;
                    $name = $from;
                    $name =~ s/\n//g;
                    # When the name contains a dot, Email::Address fails
                    # unless it is properly quoted
                    #$from =~ m/\..*</o
                    #        and $from =~ s/^[^"]{0}([^<"]+)[^"]{0}\s+</"$1" </;
                    if (my @addrs = Email::Address->parse($from)) {
                        $name = $addrs[0]->name();
                        $name =~ s/(\w+)/\u\L$1/g;  # Cap each word first char
                    }
                    last SWITCH;
                };

            index($_, 'Status: R') == 0
                # Message is read aka old
                # There are four possibilities
                #   1. no status line, unread and unseen
                #   2. O, seen and unread
                #   3. R, unseen and read
                #   4. RO, seen and read
                # NB:
                #   A message marked as "seen" as soon as we open the mbox
                #   We want to match cases 3 and 4.
                && do {
                    $is_old = 1;
                    last SWITCH;
                };

            index($_, 'X-Status: D') == 0
                # Message is marked for deletion
                && do {
                    $is_del = 1;
                    last SWITCH;
                };

            m{^$}
                # Leave headers
                && do {
                    $in_head = 0;
                    # Buggy mail if no or empty 'From: ' line
                    $bug++ unless $name;
                    # Count new messages that are not marked for deletion
                    if (!$is_old && !$is_del) {                # XXX
                        $new++;
                        $whos{$name}++ if $name;
                    }
                    last SWITCH;
                };

            $all == 1 && index($_, 'X-IMAP: ') == 0
                # Skip Pine annoying message
                && do {
                    $all--;
                    last SWITCH;
                };

            }
        }

        close($mbox) or warn "Can't close $_path_: $!\n";
    };

    ### Summary closure
    my $summary = sub {
        my($_folder_count_) = @_;

        unless ($_quiet_) {
            my $mbox = $_mbox_;
            $mbox = "*$mbox" unless $use_cache;
            printf "  %-22s %+s\t", $mbox, $all;
            print "($new)"      if $new;
            print "\t!$bug!"    if $bug;
            print "\n";
        }

        ### Update cache

        unless ($use_cache) {
            %{ $_caches_->{COUNT}{$_folder_}{$_mbox_} } = (
                TIMESTAMP   => time,
                ALL         => $all,
                NEW         => $new,
                BUG         => $bug,
            );
            $_caches_->{WHO}{$_folder_}{$_mbox_} = \%whos;
        }

        &$_folder_count_($new, $all);
    };

    return($count, $summary);
}

# >> (undef) / 1
sub dump_cache {
    my($_cache_, $_level_) = @_;

    require Data::Dumper;

    unless (-e $_cache_) {
        print "No cache found\n";
        return;
    }
    my $caches = retrieve($_cache_);
    my $dumper = Data::Dumper->new([$caches], [('Caches')]);
    $dumper->Indent(1)->Quotekeys(0)->Maxdepth($_level_);
    print $dumper->Dump;
    1;
}

# Split a comma separated string, trim leading and trailing whitespaces
# >> (array)
sub _split {
    return if not defined $_[0];
    my @list = split /,/, $_[0];
    foreach (@list) {
        s/^\s+//; s/\s+$//;
    }
    return @list;
}

# >> (hashref)
sub _tree {
    my($_folders_, $_mboxes_) = @_;
    my %tree;
    my $dir;

  RULE:
    foreach (_split $_mboxes_) {
        if (m/{(.*)}(.*)/) {
            if ($1) {
                # $1 = folder
                if ($2) {
                    # $2 = mbox
                    # A more general rule already exists
                    next RULE if exists $tree{$1} and !%{ $tree{$1} };
                    $tree{$1}{$2} = undef;
                }
                else {
                    # All mboxes
                    $tree{$1} = {};
                }
            }
            else {
                # All folders
                if ($2) {
                    # $2 = mbox
                    foreach $dir (@$_folders_) {
                        # A more general rule already exists
                        next RULE if exists $tree{$dir} and !%{ $tree{$dir} };
                        $tree{$dir}{$2} = undef;
                    }
                }
                else {
                    # All mboxes
                    foreach $dir (@$_folders_) { $tree{$dir} = {}; }
                }
            }
        }
        else {
            # All folders and $_ = mbox
            foreach $dir (@$_folders_) {
                # A more general rule already exists
                next RULE if exists $tree{$dir} and !%{ $tree{$dir} };
                $tree{$dir}{$_} = undef;
            }
        }
    }
    return \%tree;
}

# >> (arrayref)
sub _collection {
    my $found   = 0;
    my @collection;

    my $path = $_[0] || catfile($ENV{HOME}, '.pinerc');
    open my $pinerc, '<', $path or return \@collection;
  LINE:
    while (<$pinerc>) {
	next LINE if m/^#/;
	# !!! WARNING !!!
	# Do not remove leading whitespaces, they are important in order to
	# separate single-valued from multi-valued options
	chomp;
	s/\s+$//;
	next LINE unless length;
	if (s/^\s+//) {
	    # Middle or end of a multi-valued option

	    next LINE unless $found;
            push @collection, $_;
	    last LINE unless s/,$//;
	}
        elsif (s/,$//) {
	    # Start of a multi-valued option

	    m/^(.+?)=(.*)$/;
            if ($1 eq 'folder-collections') {
                $found = 1;
                push @collection, $2;
            }
	}
        else {
	    # One-line option (multi-valued or not)

	    m/^(.+?)=(.*)$/;
            next LINE unless $1 eq 'folder-collection';
            push @collection, $2 if $2;
	    last LINE;
	}
    }

    close $pinerc or warn "Can't close $path: $!\n";
    return \@collection;
}

__END__
