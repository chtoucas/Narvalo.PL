$|++;

use strict;
use warnings;
use feature     qw(say switch);
use utf8;

BEGIN {
    use FindBin     qw($Bin);
    use lib         qq{$Bin/../lib};
}

use DateTime;
use Getopt::Std                 qw(getopts);
use Narvalo::Bookkeeping::Utils qw(ymd_is_wellformed);
use Narvalo::Bookkeeping::Transactions;

binmode(STDOUT, ':utf8');

MAIN:
{
    # Command-line options
    my %opts;
    die "Usage: $0 [-e <date> -f <file>]" unless getopts('e:f:', \%opts);

    my $xml = $opts{f};
    $xml ||= 'book.xml';
    die "Missing input file $xml" unless -f $xml;

    my $end_ymd;
    if ($opts{e}) {
        $end_ymd = $opts{e};
        $end_ymd =~ s{'}{}g;

        die "Invalid date $end_ymd" unless ymd_is_wellformed($end_ymd);
    }
    else {
        $end_ymd = DateTime->now()->ymd;
    }

    #
    my $parser = Narvalo::Bookkeeping::Transactions->new();
    $parser->parse($xml, {'end_ymd' => $end_ymd});
    my $banks = $parser->banks();

    #
    my($cash, $credit, $asset, $investment) = (0, 0, 0, 0);

    say "$end_ymd\n----------\n";

    while (my($bic, $bank) = each(%$banks)) {
        say $bank->{name};

        my $balance = 0;

        while (my($iban, $account) = each(%{ $bank->{accounts} })) {
            my $transactions = $account->{transactions};

            # Compute cash & credit
            my($account_cash, $account_credit)
            = ($account->{opening_balance}, 0);

            foreach my $date (sort keys %$transactions) {
                my @transactions = @{ $transactions->{$date} };

                foreach my $transaction (@transactions) {
                    my $sign;

                    given ($transaction->{type}) {
                        when ('DEBIT')      { $sign = -1; }
                        when ('BENEFIT')    { $sign = +1; }
                        when ('TRANSFER')   { $sign = -1; }
                        when ('DEPOSIT')    { $sign = +1; }
                        when ('WITHDRAWAL') { $sign = -1; }
                        when ('INTEREST')   { $sign = +1; }
                    }

                    if ($transaction->{is_cleared}
                        || !$transaction->{is_delayed}) {
                        $account_cash += $sign * $transaction->{amount};
                    }
                    else {
                        $account_credit += $sign * $transaction->{amount};
                    }
                }
            }

            # Print the account's summary
            given ($account->{type}) {
                when ('CASH') {
                    $cash    += $account_cash;
                    $credit  += $account_credit;
                    $balance += $account_cash + $account_credit;

                    printf "   %-15s| %8.2f\n", 'Courant', $account_cash;
                    printf "   %-15s| %8.2f\n", 'Différé', $account_credit
                        if $account_credit;
                }

                when ('ASSET') {
                    $asset += $account_cash;

                    printf "   %-15s| %8.2f (%-s)\n",
                    'Épargne CT', $account_cash, $account->{name};
                }

                when ('INVESTMENT') {
                    $investment += $account_cash;

                    printf "   %-15s| %8.2f (%-s)\n",
                    'Épargne LT', $account_cash, $account->{name};
                }
            }
        }

        printf "   %-15s# %8.2f\n\n", 'Balance', $balance;
    }

    # Print summary
    my $real = $cash + $credit;

    say "Résumé";
    printf "   %-15s| %8.2f\n",   'Courant',    $cash;
    printf "   %-15s| %8.2f\n",   'Différé',    $credit;
    printf "   %-15s# %8.2f\n\n", 'Balance',    $real;
    printf "   %-15s| %8.2f\n",   'Épargne CT', $asset;
    printf "   %-15s| %8.2f\n\n", 'Épargne LT', $investment;
    printf "   %-15s# %8.2f\n",   'Disponible', ($real + $asset);
    printf "   %-15s| %8.2f\n\n", 'Patrimoine', ($real + $asset + $investment);
}

__END__
