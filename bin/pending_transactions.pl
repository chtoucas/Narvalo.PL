$|++;

use strict;
use warnings;
use feature         qw(say);
use utf8;

BEGIN {
    use FindBin     qw($Bin);
    use lib         qq{$Bin/../lib};
}

use DateTime;
use Getopt::Std     qw(getopts);
use Soldi::Transactions::NotCleared;
use Soldi::Utils    qw(ymd_is_wellformed);

binmode(STDOUT, ':utf8');

MAIN:
{
    # Command-line options
    my %opts;
    die "Usage: $0 [-e <date> -t <type> -f <file>]"
    unless getopts('e:t:f:', \%opts);

    my $xml = $opts{f};
    $xml ||= 'xml/soldi.xml';
    die "Missing input file $xml" unless -f $xml;

    my $type = $opts{t} if $opts{t};

    my $end_ymd;
    if ($opts{e}) {
        $end_ymd = $opts{e};
        $end_ymd =~ s{'}{}g;

        die qq{Invalid end date $end_ymd} unless ymd_is_wellformed($end_ymd);
    }
    else {
        $end_ymd = DateTime->now()->ymd;
    }

    #
    my $transactions = Soldi::Transactions::NotCleared->new();
    $transactions->parse($xml, {type => $type, end_ymd => $end_ymd});
    my %transactions = %{ $transactions->result() };

    if (%transactions) {
        while (my($account, $transactions) = each(%transactions)) {
            say $account;

            printf "   %-12s %-27s %8.2f\n", @$_ foreach @$transactions;
        }
    }
    else {
        say "No transactions";
    }
}

__END__
