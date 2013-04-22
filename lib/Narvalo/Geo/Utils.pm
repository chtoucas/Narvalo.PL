package Narvalo::Geo::Utils;

use strict;
use warnings;

use base qw(Narvalo::Geo);

use Carp;
use Perl6::Export::Attrs;
{
    my $QPREFIXES = {
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
    my $PREFIXES = { map {
        my $qprefix = $QPREFIXES->{$_};
        $_ => $qprefix->[0] . ($qprefix->[1] ? q{ } : q{})
    } keys %$QPREFIXES };
    my $REVERSED_PREFIXES = {
        map { $PREFIXES->{"$_"} => $_ }
        grep { $QPREFIXES->{$_}->[0] } keys %$QPREFIXES
    };
    my $PREFIXES_STR = join(q{|}, keys %$REVERSED_PREFIXES);
    my $LEADING_PREFIXES = qr{\A($PREFIXES_STR)(.*)\z}ims;

    sub format_name :Export(:DEFAULT) {
        return $PREFIXES->{$_[0]} . $_[1];
    }

    sub parse_dirty_name :Export(:DEFAULT) {
        my $name = shift;
        my($qname, $qprefix);

        # Remove prefix
        if ($name =~ m{$LEADING_PREFIXES}) {
            $qprefix = $REVERSED_PREFIXES->{ucfirst(lc $1)};
            $qname = $2;
        }
        else {
            $qprefix = $name =~ m{\A[aeiouy]}i ? 1 : 0;
            $qname = $name;
        }

        # Cleanup qname
        $qname =~ s{(?:-|_)}{ }g;
        $qname =~ s{\s+}{ }g;
        $qname = ucfirst($qname);
        $qname =~ tr/ /-/;

        return($qprefix, $qname);
    }
}

1;
