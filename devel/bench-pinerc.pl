#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { use lib '../lib'; }

use Benchmark   qw(cmpthese timethese);

use Mail::Pine::Pinerc;

my $path = '../t/pinerc';

my $std_heavy_pinerc = Mail::Pine::Pinerc->new(Path => $path);
my $std_light_pinerc = Mail::Pine::Pinerc->new(
    Path => $path,
    Opts => [
    'user-domain', 'personal-name', 'address-book',
    'feature-list', 'alt-addresses'
    ]
);
my $custom_heavy_pinerc = Mail::Pine::Pinerc->new();
my $custom_light_pinerc = Mail::Pine::Pinerc->new(
    Opts => [
    'user-domain', 'personal-name', 'address-book',
    'feature-list', 'alt-addresses'
    ]
);

cmpthese(100, {
        'Fresh Full'    =>  sub { $std_heavy_pinerc->parse() },
        'Fresh Part'    =>  sub { $std_light_pinerc->parse() },
        'Custom Full'   =>  sub { $custom_heavy_pinerc->parse() },
        'Custom Part'   =>  sub { $custom_light_pinerc->parse() },
    } );

# EOF
