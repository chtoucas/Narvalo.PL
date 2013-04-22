package Narvalo::Geo::Config;

die "BROKEN";

{
    our $QPrefixes = {
        '0'   => [q{},    0,    q{De}],
        '1'   => [q{},    0,    q{D'}],
        '2'   => [q{Le},  1,    q{Du}],
        '3'   => [q{La},  1,    q{De la}],
        '4'   => [q{Les}, 1,    q{Des}],
        '5'   => [q{L'},  0,    q{De l'}],
        '6'   => [q{Aux}, 1,    q{Des}],
        '7'   => [q{Las}, 1,    q{De las}],
        '8'   => [q{Los}, 1,    q{De los}],
    };

    our $Prefixes = { map {
        my $qprefix = $QPrefixes->{$_};
        $_ => $qprefix->[0] . ($qprefix->[1] ? q{ } : q{})
    } keys %$QPrefixes };
    our $ReversedPrefixes = {
        map { $Prefixes->{"$_"} => $_ }
        grep { $QPrefixes->{$_}->[0] } keys %$QPrefixes
    };
}

1;
