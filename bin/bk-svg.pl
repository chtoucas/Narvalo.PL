$|++;

use strict;
use warnings;

BEGIN {
    use FindBin     qw($Bin);
    use lib         qq{$Bin/../lib};
}

use feature     qw(switch);
use charnames   qw(:full);
use utf8;

use Cwd                         qw(getcwd);
use DateTime;
use Getopt::Std                 qw(getopts);
use Narvalo::Bookkeeping::Transactions;
use Narvalo::Bookkeeping::Utils qw(:ALL);
use Time::Local;
use SVG::TT::Graph::TimeSeries;

binmode(STDOUT, ':utf8');

MAIN:
{
    # Command-line options
    my %opts;
    die "Usage: $0 [-c -t -i <iban> -s <date> -e <date> -f <file>]"
        unless getopts('cti:s:e:f:', \%opts);

    my($with_total, $_iban) = ($opts{t}, $opts{i});
    $with_total = 0 if $_iban;

    # Determine requested start and end dates
    my($start, $end) = get_dates($opts{s}, $opts{e});

    # Parse data file
    my $banks = parse_xml($opts{f}, $end, $opts{c});;

    # Compute actual start and end dates if none requested
    $start ||= get_start_ymd($banks, $_iban);

    # Compute x-scale
    # Force graph to start at beginning of month or year
    my($min_division, $x_scale);
    ($start, $min_division, $x_scale) = get_x_scale($start, $end);

    # Prepare graph data
    my %accounts = ();
    my($min_balance, $max_balance) = (0, 0);
    my $require_fix = 1;    # XXX
  BANK:
    while (my($bic, $bank) = each(%$banks)) {
      ACCOUNT:
        while (my($iban, $account) = each(%{ $bank->{accounts} })) {
            next ACCOUNT if $_iban && $iban ne $_iban;
                # To be removed

            my $balance = $account->{opening_balance};
            my $opening_ymd = $account->{opening_date};
            next ACCOUNT if is_after($opening_ymd, $end);

            my $closing_ymd = $account->{closing_date};
            next ACCOUNT if $closing_ymd && is_before($closing_ymd, $start);

            my $transactions = $account->{transactions};
            my $balances = {};
          TRANSACTION:
            foreach my $ymd (sort keys %{$transactions}) {
                # Bypass out of range transactions
                last TRANSACTION if is_after($ymd, $end);

                foreach my $transaction (@{ $transactions->{$ymd} }) {
                    $balance += get_transaction_sign($transaction->{type})
                              * $transaction->{amount};
                }

                $balances->{$ymd} = $balance if is_after_or_equal($ymd, $start);
            }

            # Complete the graph with the first possible balance
            # either at graph's start date or at account's opening date
            {
                my $ymd;
                my $amount;

                if (is_after_or_equal($opening_ymd, $start)) {
                    $ymd = $opening_ymd;
                    $amount = $account->{opening_balance};
                }
                else {
                    $require_fix = 0;
                        # XXX
                    $ymd = $start;
                    my @ymds = sort keys %$balances;
                    $amount = !@ymds      ? $balance
                            : $#ymds == 1 ? $balances->{ $ymds[0] }
                            : $account->{opening_balance};
                }

                $balances->{$ymd} = $amount unless exists $balances->{$ymd};
            }

            # Complete the graph with the last possible balance either
            # at graph's end date or at account's closing date if available
            {
                my $ymd = $end;
                $ymd = $closing_ymd
                    if $closing_ymd && is_before($closing_ymd, $ymd);
                $balances->{$ymd} = $balance unless exists $balances->{$ymd};
            }

            # Prepare SVG data
            my @ymds = sort keys %$balances;
            my $prev_date = ymd2date($ymds[0]);
            my $prev_balance;
            my @balances = ();

          EVOLUTION:
            foreach my $ymd (@ymds) {
                # Fill the graph
                while (1) {
                    $prev_date = $prev_date + $min_division;
                    last if is_after_or_equal($prev_date->ymd, $ymd);
                    push_balance(\@balances, $prev_date->ymd, $prev_balance);
                }

                # Push result
                my $y = $balances->{$ymd};
                push_balance(\@balances, $ymd, $y);

                # Process min and max amounts
                $min_balance = $y if $y < $min_balance;
                $max_balance = $y if $y > $max_balance;

                # Prepare next iteration
                $prev_date    = ymd2date($ymd);
                $prev_balance = $y;
            }

            $accounts{$bank->{name} . ': ' . $account->{name}} = \@balances;
        }
    }

    #
    if ($with_total) {
        my %amounts = ();

      BANK:
        while (my($bic, $bank) = each(%$banks)) {
          ACCOUNT:
            while (my($iban, $account) = each(%{ $bank->{accounts} })) {
                next ACCOUNT if $_iban && $iban ne $_iban;
                    # To be removed

                my $opening_ymd = $account->{opening_date};
                next ACCOUNT if is_after($opening_ymd, $end);

                add_hashval(\%amounts, $opening_ymd, $account->{opening_balance});
                my $transactions = $account->{transactions};

              TRANSACTION:
                foreach my $ymd (sort keys %$transactions) {
                    # Remaining transactions are out of range
                    last TRANSACTION if is_after($ymd, $end);

                    my $total = 0;

                    foreach my $transaction (@{ $transactions->{$ymd} }) {
                        $total += get_transaction_sign($transaction->{type})
                                * $transaction->{amount};
                    }

                    add_hashval(\%amounts, $ymd, $total);
                }
            }
        }

        my @balances;
        my @ymds = sort keys %amounts;

        #XXX push_balance(\@balances, $start, $amounts{$ymds[0]})
        #XXX     unless exists $amounts{$start};

        my $balance = 0;
        foreach my $ymd (@ymds) {
            $balance += $amounts{$ymd};

            if (is_after_or_equal($ymd, $start)) {
                push_balance(\@balances, $ymd, $balance);

                $min_balance = $balance if $balance < $min_balance;
                $max_balance = $balance if $balance > $max_balance;
            }
        }

        push_balance(\@balances, $end, $balance)
            unless exists $amounts{$end};
        $accounts{'Total'} = \@balances;
    }

    # XXX Not restrictive enough

    # XXX if ($real_start_ymd ne $start) {
    if ($require_fix) {
        $accounts{'fake'} = ["$start 00:00:00", 0];
    }

    ##
    my $scale_divisions;
    {   # We try to find the best scale in order to have around 10 divisions
        #  on the y-axis
        my $range = $max_balance + ($min_balance < 0 ? - $min_balance : 0);
        my $pow = 0;
        $pow++ while ($range > 10**$pow);
        $scale_divisions = 10**--$pow;
        $scale_divisions /= 2
            while (1 + sprintf("%u", $range / $scale_divisions) <= 5);
    }

    my($min_y, $max_y) = (0, 0);

    if ($min_balance >= 0) {
        $min_y = 0;
        $max_y += $scale_divisions while $max_y < $max_balance;
    }
    else {
        $min_y -= $scale_divisions while $min_y > $min_balance;
        $max_y += $scale_divisions while $max_y < $max_balance;
    }

    #
    my($x_label_format, $timescale_divisions, $height,
       $width, $show_data_points) = get_scales($start, $end, $x_scale);

    my $graph_subtitle
        = "Min: " . sprintf("%.2f", $min_balance) . qq{ \N{EURO SIGN} / Max: }
        . sprintf("%.2f", $max_balance) . qq{ \N{EURO SIGN}};

    my $graph = SVG::TT::Graph::TimeSeries->new({
        'rollover_values'   => 1,
        'area_fill'         => 1,
        'height'            => $height,
        'width'             => $width,
        'min_scale_value'   => $min_y,
        'max_scale_value'   => $max_y,
        'stagger_x_labels'  => 0,
        'x_label_format'    => $x_label_format,
        'rotate_x_labels'   => 0,
        'show_graph_title'  => 1,
        'graph_title'       => "Du $start au $end",
        'show_graph_subtitle'  => 1,
        'graph_subtitle'    => $graph_subtitle,
        'key'               => 1,
        'key_position'      => 'bottom',
        'timescale_divisions' => $timescale_divisions,
        'scale_divisions'    => $scale_divisions,
        #'max_time_span'     => '1 months',
        'show_data_points'  => $show_data_points,
        'show_data_values'  => 1,
        'y_title'           => 'Balance',
        'x_title'           => 'Date',
        #'compress'          => 1,
    });

    foreach my $label (sort keys %accounts) {
        $graph->add_data({
            data  => $accounts{$label},
            title => $label,
        });
    }

    print $graph->burn();
}

################################################################################

sub get_dates {
    my($start, $end) = @_;
    if ($end) {
        $end =~ s{'}{}gxms;
        die qq{Invalid end date '$end'} unless ymd_is_wellformed($end);
    }
    else {
        $end = DateTime->now()->ymd;
    }
    if ($start) {
        $start =~ s{'}{}gxms;
        die qq{Invalid start date '$start'} unless ymd_is_wellformed($start);
        die  q{Invalid date range}              if is_after($start, $end);
    }
    return($start, $end);
}

sub parse_xml {
    my($xml, $end, $type) = @_;
    $xml ||= 'book.xml';
    die qq{Missing input file '$xml'} unless -f $xml;

    # Parse the file
    # XXX Add filter on iban
    my $parser = Narvalo::Bookkeeping::Transactions->new();
    $parser->parse($xml, {end_ymd => $end, type => $type ? 'CASH' : undef,});

    return $parser->banks();
}

sub push_balance {
    push @{$_[0]}, "$_[1] 00:00:00", sprintf("%.0f", $_[2]);
}

sub get_start_ymd {
    my($banks, $_iban) = @_;
    my($start, $end);
  BANK:
    while (my($bic, $bank) = each(%$banks)) {
      ACCOUNT:
        while (my($iban, $account) = each(%{ $bank->{accounts} })) {
            next ACCOUNT if $_iban && $iban ne $_iban;      # XXX To be removed

            my $ymd = $account->{opening_date};

            if (defined $start) {
                $start = $ymd if is_before($ymd, $start);
            }
            else {
                $start = $ymd
            }
        }
    }
    return $start;
}

sub get_transaction_sign {
    my $sign;
    given ($_[0]) {
        when ('BENEFIT')    { $sign = +1; }
        when ('DEPOSIT')    { $sign = +1; }
        when ('INTEREST')   { $sign = +1; }
        when ('DEBIT')      { $sign = -1; }
        when ('TRANSFER')   { $sign = -1; }
        when ('WITHDRAWAL') { $sign = -1; }
        default             { die "Unknown transaction type " . $_[0]; }
    }
    return $sign;
}

################################################################################

sub get_x_scale {
    my($start_ymd, $end_ymd) = @_;

    my $start_date = ymd2date($start_ymd);
    my $range = ymd2date($end_ymd) - $start_date;

    my $x_scale = $range->in_units('years')  >= 1 ? 'YEARS'
                : $range->in_units('months') >= 1 ? 'MONTHS'
                : 'DAYS';

    my $min_division;
    given ($x_scale) {
        when ('YEARS') {
            # >= 1 year
            $min_division = DateTime::Duration->new(months => 1);
            # To ensure graph x-labels to be correctly displayed
            $start_date->set_month(1);
            $start_date->set_day(1);
            $start_ymd = $start_date->ymd;
        }
        when ('MONTHS') {
            # >= 1 month && < 1 year
            $min_division = DateTime::Duration->new(weeks => 1);
            # To ensure graph x-labels to be correctly displayed
            $start_date->set_day(1);
            $start_ymd = $start_date->ymd;
        }
        when ('DAYS') {
            # < 1 month
            $min_division = DateTime::Duration->new(days => 1);
        }
    }

    return($start_ymd, $min_division, $x_scale);
}

sub get_scales {
    my($start_ymd, $end_ymd, $x_scale) = @_;

    my($x_label_format, $timescale_divisions, $height,
       $width, $show_data_points);
    given ($x_scale) {
        when ('YEARS') {
            $x_label_format = '%Y';
            $timescale_divisions = '1 years';
            $height = 750;
            $width = 1550;
            $show_data_points = 0;
        }
        when ('MONTHS') {
            my $range = ymd2date($end_ymd) - ymd2date($start_ymd);

            if ($range->in_units('months') >= 2) {
                $x_label_format = '%m';
                $timescale_divisions = '1 months';
            }
            else {
                $x_label_format = '%d';
                $timescale_divisions = '1 days';
            }

            $show_data_points = 1;
            $height = 750;
            $width = 1550;
        }
        when ('DAYS') {
            $x_label_format = '%d';
            $timescale_divisions = '1 days';
            $height = 750;
            $width = 1550;
            $show_data_points = 1;
        }
    }

    return($x_label_format, $timescale_divisions, $height,
        $width, $show_data_points);
}




sub fix_start_date {
    my($start_ymd, $end_ymd) = @_;

my %scales;

    my $start_date = ymd2date($start_ymd);
    my $range = ymd2date($end_ymd) - $start_date;

    my $x_scale = $range->in_units('years')  >= 1 ? 'YEARS'
                : $range->in_units('months') >= 1 ? 'MONTHS'
                : 'DAYS';

    given ($scales{x_scale}) {
        when ('YEARS') {
            # >= 1 year
            # To ensure x-labels to be correctly displayed
            $start_date->set_month(1);
            $start_date->set_day(1);
            $start_ymd = $start_date->ymd;
        }
        when ('MONTHS') {
            # >= 1 month && < 1 year
            # To ensure x-labels to be correctly displayed
            $start_date->set_day(1);
            $start_ymd = $start_date->ymd;
        }
        when ('DAYS') {
            # < 1 month
            ;
        }
    }

    return $start_ymd;
}

sub _get_scales {
    my($start_ymd, $end_ymd) = @_;

    my %scales;

    my $start_date = ymd2date($start_ymd);
    my $range = ymd2date($end_ymd) - $start_date;

    my $x_scale = $range->in_units('years')  >= 1 ? 'YEARS'
                : $range->in_units('months') >= 1 ? 'MONTHS'
                : 'DAYS';

    given ($scales{x_scale}) {
        when ('YEARS') {
            # >= 1 year
            %scales = (
                x_scale     => $x_scale,
                x_format    => q{%Y},
                x_div       => DateTime::Duration->new(months => 1),
                x_range     => '1 years',
                show_points => 0,
                height      => 750,
                width       => 1550,
            );
        }
        when ('MONTHS') {
            # >= 1 month && < 1 year
            $scales{min_division} = DateTime::Duration->new(weeks => 1);
            if ($range->in_units('months') >= 2) {
                $scales{x_label_format} = q{%m};
                $scales{timescale_divisions} = '1 months';
            }
            else {
                $scales{x_label_format} = q{%d};
                $scales{timescale_divisions} = '1 days';
            }
            $scales{show_data_points} = 1;
            $scales{height} = 750;
            $scales{width} = 1550;
        }
        when ('DAYS') {
            # < 1 month
            %scales = (
                x_scale     => $x_scale,
                x_format    => q{%d},
                x_div       => DateTime::Duration->new(days => 1),
                x_range     => '1 days',
                show_points => 1,
                height      => 750,
                width       => 1550,
            );
        }
    }

    return \%scales;
}

__END__
