package Soldi::Utils;

use strict;
use warnings;

use Carp;
use DateTime;
use Perl6::Export::Attrs;
{
    my $DATE       = qr{\A\d{4}-\d{2}-\d{2}\z}xms;
    my $DATE_MATCH = qr{\A(\d{4})-(\d{2})-(\d{2})\z}xms;

    sub ymd_is_wellformed :Export(:DATE) {
        $_[0] =~ $DATE;
    }

    sub ymd2date :Export(:DATE) {
        my $ymd = $_[0];

        my @ymd = ($ymd =~ $DATE_MATCH);
        my $date = DateTime->new(
            year    => $ymd[0],
            month   => $ymd[1],
            day     => $ymd[2],
        );

        return $date;
    }

    sub is_before :Export(:DATE) {
        (sort @_)[0] eq $_[0];
    }

    sub is_after :Export(:DATE) {
        (sort @_)[0] ne $_[0];
    }

    sub is_before_or_equal :Export(:DATE) {
        $_[0] eq $_[1] || (sort @_)[0] eq $_[0];
    }

    sub is_after_or_equal :Export(:DATE) {
        $_[0] eq $_[1] || (sort @_)[0] ne $_[0];
    }

    sub add_hashval :Export(:HASH) {
        my($hash, $key, $value) = @_;

        if (exists $hash->{$key}) {
            $hash->{$key} += $value;
        }
        else {
            $hash->{$key} = $value;
        }
    }
}

1;

__END__
