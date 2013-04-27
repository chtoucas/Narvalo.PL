package Narvalo::Bookkeeping::Transactions::All;

use strict;
use warnings;
use feature     qw(switch);
use utf8;

use Carp;
use Narvalo::Bookkeeping::Utils     qw(is_after is_before);
use XML::SAX::ParserFactory;
{
    sub new {
        bless {
            #
            'banks'             => {},

            # Runtime options
            'start_ymd'         => undef,
            'end_ymd'           => undef,
            'type'              => undef,
            'groupby'           => undef,

            # XML states
            '_in_Account'       => 0,
            '_in_Opening'       => 0,
            '_in_Balance'       => 0,
            '_in_Closing'       => 0,
            '_in_Transaction'   => 0,
            '_in_Date'          => 0,
            '_in_Amount'        => 0,
            '_in_Actor'         => 0,
            '_in_Payer'         => 0,
            '_in_Category'      => 0,

            # Temporary variables
            '_bank'             => {},
            '_accounts'         => {},
            '_account'          => {},
            '_transactions'     => {},
            '_transaction'      => {},

            '_bypass_transaction'   => 0,
            '_bypass_account'       => 0,
        }, shift;
    }

    #
    # Public methods
    #

    sub parse {
        my($self, $_xml_, $_cnf_) = @_;

        if ($_cnf_->{start_ymd}) {
            $self->{start_ymd} = $_cnf_->{start_ymd};
        }

        if ($_cnf_->{end_ymd}) {
            $self->{end_ymd} = $_cnf_->{end_ymd};
        }

        if ($_cnf_->{type}) {
            $self->{type} = $_cnf_->{type};
        }

        #$XML::SAX::ParserPackage = "XML::LibXML::SAX";
        my $parser = XML::SAX::ParserFactory->parser(Handler => $self);
        $parser->parse_uri($_xml_);
    }

    sub banks {
        return $_[0]->{banks};
    }

    #
    # SAX methods
    #

    sub start_element {
        my($self, $_props_) = @_;

        given ($_props_->{Name}) {
            when ('Transaction') {
                $self->{_in_Transaction} = 1;

                # Create a brand new transaction
                $self->{_transaction} = {
                    date        => undef,
                    amount      => 0,
                    type        => 'UNKNOWN',
                    actor       => '',
                    category    => '',
                    is_delayed  => $_props_->{Attributes}->{'{}delayed'},
                    is_cleared  => $_props_->{Attributes}->{'{}cleared'},
                };
            }

            when ('Payee') {
                $self->{_in_Actor} = 1;
                $self->{_transaction}->{type} = 'DEBIT';
            }
            when ('Payer') {
                $self->{_in_Actor} = 1;
                $self->{_transaction}->{type} = 'BENEFIT';
            }
            when ('Transfer')   {
                $self->{_transaction}->{type} = 'TRANSFER';
            }
            when ('Deposit')    {
                $self->{_transaction}->{type} = 'DEPOSIT';
            }
            when ('Withdrawal') {
                $self->{_transaction}->{type} = 'WITHDRAWAL';
            }
            when ('Interest')   {
                $self->{_transaction}->{type} = 'INTEREST';
            }

            when ('Date')       { $self->{_in_Date}    = 1; }
            when ('Amount')     { $self->{_in_Amount}  = 1; }
            when ('Category')   { $self->{_in_Category} = 1; }
            when ('Opening')    { $self->{_in_Opening} = 1; }
            when ('Closing')    { $self->{_in_Closing} = 1; }
            when ('Balance')    { $self->{_in_Balance} = 1; }

            when ('Account') {
                $self->{_in_Account} = 1;

                my $type = $_props_->{Attributes}->{'{}type'}->{Value};

                $self->{_bypass_account}
                = $self->{type}
                ? $type ne $self->{type}
                : 0;

                # Create a brand new account
                $self->{_account} = {
                    iban => $_props_->{Attributes}->{'{}iban'}->{Value},
                    name => $_props_->{Attributes}->{'{}name'}->{Value},
                    type => $type,
                    opening_date    => undef,
                    opening_balance => undef,
                    closing_date    => undef,
                };

                $self->{_transactions} = {};
            }
            when ('Bank') {
                # Create a brand new bank
                $self->{_bank} = {
                    bic     => $_props_->{Attributes}->{'{}bic'}->{Value},
                    name    => $_props_->{Attributes}->{'{}name'}->{Value},
                };

                $self->{_accounts} = {};
            }
        }
    }

    sub end_element {
        my($self, $_props_) = @_;

        my $name = $_props_->{Name};

        if ($self->{_in_Transaction} && $name ne 'Transaction' && $name ne 'Date') {
            return if $self->{_bypass_transaction};
        }

        given ($name) {
            when ('Transaction') {
                if (!$self->{_bypass_transaction}) {
                    my $transactions = $self->{_transactions};
                    my $transaction = $self->{_transaction};

                    if ($transactions->{ $transaction->{date} }) {
                        push @{ $self->{_transactions}{ $transaction->{date} } }, {
                            amount      => $transaction->{amount},
                            type        => $transaction->{type},
                            actor       => $transaction->{actor},
                            category    => $transaction->{category},
                            is_delayed  => $transaction->{is_delayed},
                            is_cleared  => $transaction->{is_cleared},
                        };
                    }
                    else {
                        $self->{_transactions}{ $transaction->{date} } = [ {
                            amount      => $transaction->{amount},
                            type        => $transaction->{type},
                            actor       => $transaction->{actor},
                            category    => $transaction->{category},
                            is_delayed  => $transaction->{is_delayed},
                            is_cleared  => $transaction->{is_cleared},
                        } ];
                    }
                }

                $self->{_in_Transaction} = 0;
            }

            when ('Category')   { $self->{_in_Category} = 0; }
            when ('Payee')      { $self->{_in_Actor} = 0; }
            when ('Payer')      { $self->{_in_Actor} = 0; }

            when ('Date')       { $self->{_in_Date}    = 0; }
            when ('Amount')     { $self->{_in_Amount}  = 0; }
            when ('Opening')    { $self->{_in_Opening} = 0; }
            when ('Closing')    { $self->{_in_Closing} = 0; }
            when ('Balance')    { $self->{_in_Balance} = 0; }

            when ('Account') {
                $self->{_in_Account} = 0;

                return if $self->{_bypass_account};

                my $account = $self->{_account};

                $self->{_accounts}->{ $account->{iban} } = {
                    name            => $account->{name},
                    type            => $account->{type},
                    opening_date    => $account->{opening_date},
                    opening_balance => $account->{opening_balance},
                    closing_date    => $account->{closing_date},
                    transactions    => $self->{_transactions}
                };
            }

            when ('Bank') {
                my $bank = $self->{_bank};

                $self->{banks}->{ $bank->{bic} } = {
                    name     => $bank->{name},
                    accounts => $self->{_accounts}
                };
            }
        }
    }

    sub characters {
        my($self, $_props_) = @_;

        my $data = $_props_->{Data};

        if ($self->{_in_Transaction}) {
            if ($self->{_in_Date}) {
                my $process
                = ( # Transaction occured before the end date
                    $self->{end_ymd}
                    ? is_before($data, $self->{end_ymd})
                    : 1
                )
                && ( # Transaction occured after the start date
                    $self->{start_ymd}
                    ? is_after($data, $self->{start_ymd})
                    : 1
                );

                $self->{_bypass_transaction} = !$process;

                $self->{_transaction}->{date} = $data
                unless $self->{_bypass_transaction};
            }
            else {
                return if $self->{_bypass_transaction};

                if ($self->{_in_Amount}) {
                    $self->{_transaction}->{amount} = $data;
                }
                elsif ($self->{_in_Actor}) {
                    $self->{_transaction}->{actor} .= $data;
                }
                elsif ($self->{_in_Category}) {
                    $self->{_transaction}->{category} .= $data;
                }
            }
        }
        elsif ($self->{_in_Opening}) {
            if ($self->{_in_Date}) {
                $self->{_account}->{opening_date} = $data;
            }
            elsif ($self->{_in_Balance}) {
                $self->{_account}->{opening_balance} = $data;
            }
        }
        elsif ($self->{_in_Closing}) {
            if ($self->{_in_Date}) {
                $self->{_account}->{closing_date} = $data;
            }
        }
    }
}

1;
