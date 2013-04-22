#!/usr/bin/perl -w

$| = 1;             # Disable output buffering

use strict;
use warnings;
use utf8;           # UTF-8 encoded script

use HTML::Entities;
use Readonly;

Readonly my $IN_ENC      => 'cp1252';
Readonly my $OUT_ENC     => 'utf8';

my %latin15_trans = (
    # Chars in win-1252 but not in iso-8859-15
    #"\x{20ac}"  => q{€},       # not in iso-8859-1 but in iso-8859-15
    "\x{201a}"  => q{"},
    "\x{0192}"  => q{f},
    "\x{201e}"  => q{"},
    "\x{2026}"  => q{...},
    "\x{2020}"  => q{},
    "\x{2021}"  => q{},
    "\x{02c6}"  => q{},
    "\x{2030}"  => q{0/00},
    #"\x{0160}"  => q{S},       # not in iso-8859-1 but in iso-8859-15
    "\x{2039}"  => q{<},
    #"\x{0152}"  => q{OE},      # not in iso-8859-1 but in iso-8859-15
    #"\x{017d}"  => q{Z},       # not in iso-8859-1 but in iso-8859-15
    "\x{2018}"  => q{"},
    "\x{2019}"  => q{"},
    "\x{201c}"  => q{"},
    "\x{201d}"  => q{"},
    "\x{2022}"  => q{.},
    "\x{2013}"  => q{-},
    "\x{2014}"  => q{-},
    "\x{02dc}"  => q{~},
    "\x{2122}"  => q{TM},
    #"\x{0161}"  => q{s},       # not in iso-8859-1 but in iso-8859-15
    "\x{203a}"  => q{>},
    #"\x{0153}"  => q{oe},      # not in iso-8859-1 but in iso-8859-15
    #"\x{017e}"  => q{z},       # not in iso-8859-1 but in iso-8859-15
    #"\x{0178}"  => q{Y},       # not in iso-8859-1 but in iso-8859-15

    # Chars in win-1252 and in iso-8859-1 but not in iso-8859-15
    "\x{00a4}"  => q{},
    "\x{00a6}"  => q{|},
    "\x{00a8}"  => q{},
    "\x{00b4}"  => q{"},
    "\x{00b8}"  => q{,},
    "\x{00bc}"  => q{1/4},
    "\x{00bd}"  => q{1/2},
    "\x{00be}"  => q{3/4},
);

my $_latin15_spec  = q{([} . join(q{}, keys %latin15_trans) . q{])};

my $latin15_spec   = qr{$_latin15_spec};
my $quote_spec     = qr{([^;])"{1,}([^;])"{1,}([^;])};
my $unquote_spec   = qr{([^;])"{1,}([^;])};

sub cleanup {
    my($item) = @_;

    # Sometimes you may see warnings concerning the following chars:
    # \x81, \x8D, \x8F, \x90, \x9D
    # They are harmless. The truth is that this should not happen
    # as these chars are not used in either win-1252 and UTF-8
    # but a "bug" in the windows API maps them to the C1 control chars
    # when converting a file from win-1252 to UTF-8.
    local $SIG{__WARN__} = sub {
        my $errmsg = join(q{.}, @_);
        $errmsg =~ s{[\r\n]+}{}g;
        warn $errmsg;
    };

    open my $infh, "<:encoding($IN_ENC)", $item or die $!;

    <$infh>;            # Bypass fields definition line

    my $temp = q{};     # Placeholder for multilines

  LINE:
    while (<$infh>) {
        # Handle multiline record
        if (!m{";$}) {
            s{[\r\n]+$}{}g;
            $temp .= $_;
            next LINE;
        }
        elsif ($temp) {
            $_ = $temp . $_;
            $temp = q{};
        }

        # Decode HTML entities
        $_ = decode_entities($_);
        # Remove control chars
        s{[[:cntrl:]]}{}g;
        # Translate latin15 un-mappable win-1252 chars
        if ($IN_ENC eq 'cp1252' && $OUT_ENC eq 'iso-8859-15') {
            s{$latin15_spec}{$latin15_trans{$1}}g;
        }
        #XXX Remove wide chars or we could just let perl throws warnings...
        # Remove ambiguities on double-quotes
        s{$quote_spec}{$1'$2'$3}g;
        s{$unquote_spec}{$1 $2}g;

        return $_;
    }
}
