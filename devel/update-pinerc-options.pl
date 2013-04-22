#!/usr/bin/perl -w

exit 1;

use strict;
use warnings;

use Getopt::Std     qw(getopts);

my %opts;
die "Usage: update-options -f <init.c>\n" unless getopts('f:', \%opts);
my $init_c;             # Usually pine-src/pine/init.c
if ($opts{'f'}) {
    $init_c = $opts{'f'};
} else {
    die "Usage: update-options -f <init.c>\n";
}


#-------------------------------------------------------------------------------
# Parse init.c
#-------------------------------------------------------------------------------

#my @str_fields;
#my @str_obsoletes;
my @lst_fields;
my @lst_obsoletes;
my $init_v = '?.???';

open(INITC, "< $init_c") or die "Can't open $init_c: $!\n";

while (<INITC>) {
    chomp;
    s/^\s+//;
    s/\s+$//;
    next unless length;
    if (/^static char rcsid\[\] = "\$Id: init.c,v ([^\s]+?)\s/) {
        $init_v = $1;
    }
    if (/^{"([\w-]*)",\s*
        ([01]?),\s?
        ([01]?),\s?
        ([01]?),\s?
        ([01]?),\s?
        ([01]?),\s?
        ([01]?),\s?
        /x) {
        #push @str_fields, $1       if $2 eq 0 and $7 eq 0;
        #push @str_obsoletes, $1    if $2 eq 1 and $7 eq 0;
        push @lst_fields, $1        if $2 eq 0 and $7 eq 1;
        push @lst_obsoletes, $1     if $2 eq 1 and $7 eq 1;
    }
}

close(INITC) or warn "Unable to close $init_c: $!\n";

## Uniquify results
#my %seen = ();
#my @strs = grep { !$seen{$_}++ } (@str_fields, @str_obsoletes);


#-------------------------------------------------------------------------------
# Create Mail::Pine::Pinerc::Option
#-------------------------------------------------------------------------------

my $mod_path = 'Option.pm';

open(MOD, "> $mod_path") or die "Can't create $mod_path: $!\n";

print MOD << "CODE;";
# Automatically generated from pine-src/pine/init.c version $init_v

package Mail::Pine::Pinerc::Option;

our \@EXPORT = qw(ismo);
use Exporter;
our \@ISA = qw(Exporter);

{
    # Hash of multivalued options
    my \%_mos;
    \@_mos{ qw(
            CODE;

print MOD "\t$_\n" foreach (sort (@lst_fields, @lst_obsoletes));

print MOD << 'CODE;';
    )} = ();

    ## Return true if option is multivalued, false otherwise
    sub ismo ($) { return exists $_mos{$_[0]}; }
}

1;
CODE;

close MOD or warn "Unable to close $mod_path: $!\n";

# EOF
