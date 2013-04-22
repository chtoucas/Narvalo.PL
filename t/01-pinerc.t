use strict;
use warnings;

#use Test::More tests => 22;
use Test::More qw(no_plan);

BEGIN { use_ok('Mail::Pine') };
BEGIN { use_ok('Mail::Pine::Pinerc') };
BEGIN { use_ok('Mail::Pine::Pinerc::Option') };

use Mail::Pine::Pinerc;

## All options retrieved

my $pinerc = Mail::Pine::Pinerc->new(Path => 't/pinerc');

ok(defined $pinerc, 'Constructor');
isa_ok($pinerc, 'Mail::Pine::Pinerc', '');

ok($pinerc->parse(), 'Parse pinerc');

is($pinerc->option('personal-name'), 'Dumb', 'Got a scalar option');
is($pinerc->option('user-domain'), '', 'Got an unset scalar option');
is_deeply($pinerc->option('address-book'), [], 'Got an unset array option');
is_deeply(
    $pinerc->option('feature-list'),
    ['compose-cut-from-cursor'],
    'Got a single-valued array option'
);
is_deeply(
    $pinerc->option('alt-addresses'),
    ['bozo@bozo.bz', 'kakou@kakou.ka', 'bingo@bingo.bi'],
    'Got a multi-valued array option'
);
is($pinerc->option('phantom'), undef, 'Got a phantom option');

## Change path and opts

$pinerc = Mail::Pine::Pinerc->new(Path => 't/pinerc');

ok(
   $pinerc->options([
	'phantom',
	'user-domain', 'personal-name', 'address-book',
	'feature-list', 'alt-addresses'
    ]),
    'Change opts'
);

ok($pinerc->parse(), 'Parse pinerc');

## Only a selection of options

is($pinerc->option('personal-name'), 'Dumb', 'Got a scalar option');
is($pinerc->option('user-domain'), '', 'Got an unset scalar option');
is_deeply($pinerc->option('address-book'), [], 'Got an unset array option');
is_deeply(
    $pinerc->option('feature-list'),
    ['compose-cut-from-cursor'],
    'Got a single-valued array option'
);
is_deeply(
    $pinerc->option('alt-addresses'),
    ['bozo@bozo.bz', 'kakou@kakou.ka', 'bingo@bingo.bi'],
    'Got a multi-valued array option'
);
#is_deeply(
#    $pinerc->options(),
#    {
#	'user-domain'	=> '',
#	'personal-name'	=> 'Dumb',
#	'address-book'	=> [],
#	'feature-list'	=> ['compose-cut-from-cursor'],
#	'alt-addresses' => ['bozo@bozo.bz', 'kakou@kakou.ka', 'bingo@bingo.bi'],
#    },
#    'Got all options'
#);
is(
    $pinerc->option('inbox-path'),
    '', # XXX undef
    'Got an unrequested scalar option'
);
#is(
#    $pinerc->option('folder-collections'),
#    undef,
#    'Got an unrequested array option'
#);
is($pinerc->option('phantom'), undef, 'Got a phantom option');

$pinerc = undef;

# EOF
