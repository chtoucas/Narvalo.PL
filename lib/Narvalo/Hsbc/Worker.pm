package Narvalo::Hsbc::Worker;

use feature qw(say);

use Carp;
use File::Basename;
use File::Find;
use File::Spec::Functions   qw(catfile);
use Narvalo::Hsbc::Transaction;
use Narvalo::Worker;
{
    use Moose;

    with 'Narvalo::Worker';

    sub run {
        my $self = shift;

        local $SIG{__WARN__} = sub { $self->logger->warn(@_); };
        local $SIG{__DIE__}  = sub { $self->logger->crit(@_); };

        $self->begin_phase('Working');

        my @fields = split /\s+/xms, do { local $/; <DATA> };

        my $dirs = $self->get_files();
      DIRECTORY:
        foreach my $dir (sort keys %$dirs) {
            continue_phase();

            my $out_file = catfile($self->out_dir, "$dir.csv");
            open my $fh, '+>:utf8', $out_file
                or die qq{Can't open '$out_file': $!};


            # Write XML header
            #say {$fh} q{<?xml version="1.0" encoding="utf-8"?>};
            #say {$fh} q{<TRANSACTIONS>};

            my @files = map { catfile($self->in_dir, $dir, $_) }
                        @{$dirs->{$dir}};
            my $count = $#fields;

            print {$fh} q{"} . join(q{";"}, @fields) . qq{"\r\n};

          FILE:
            foreach my $file (sort @files) {
                my $it = Narvalo::Hsbc::Transaction::Iterator->new(file => $file);
              TRANSACTION:
                while (my $transaction = $it->next()) {
                    my @trans;

                    for my $i (0...$count) {
                        push @trans, $transaction->{$fields[$i]};
                    }

                    #say {$fh} q{<TRANSACTION>};
                    #print {$fh} q{"} . $transaction->{$_} . qq{"}
                        #foreach @fields;
                    print {$fh} q{"} . join(q{";"}, @trans) . qq{"\r\n};
                        #foreach keys %{$trans};
                    #say {$fh} q{</TRANSACTION>};
                }
            }

            # Write XML footer
            #say {$fh} q{</TRANSACTIONS>};

            close $fh or warn qq{Can't close '$out_file': $!};
        }

        $self->end_phase();
    }

    sub get_files {
        my %dirs;

        my $callback = sub {
            return if m{^(?:\.|\.\.)$}i || -d $_;

            my $basename = basename($File::Find::dir);
            if (exists $dirs{$basename}) {
                push @{$dirs{$basename}}, $_;
            }
            else {
                $dirs{$basename} = [$_];
            }
        };

        find($callback, shift->in_dir);

        return \%dirs;
    }

    sub _build_subdir   { shift->_local_conf()->{subdir} }
    sub _local_conf     { shift->conf->{hsbc} }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__DATA__
ENTETE	TRANSACTION_ID	MERCHANT_ID	PAYMENT_MEANS	ORIGIN_AMOUNT	AMOUNT	CURRENCY_CODE	PAYMENT_DATE	PAYMENT_TIME	CARD_VALIDITY	CARD_TYPE	CARD_NUMBER	RESPONSE_CODE	CVV_RESPONSE_CODE	COMPLEMENTARY_CODE	CERTIFICATE	AUTHORIZATION_ID	CAPTURE_DATE	TRANSACTION_STATUS	RETURN_CONTEXT	AUTORESPONSE_STATUS	ORDER_ID	CUSTOMER_ID	CUSTOMER_IP_ADDRESS	ACCOUNT_SERIAL	SESSION_ID	TRANSACTION_CONDITION	CAVV_UCAF	COMPLEMENTARY_INFO	BANK_RESPONSE_CODE
