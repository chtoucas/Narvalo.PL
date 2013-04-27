package Narvalo::Bookkeeping::PendingTransactions;

use strict;
use warnings;
use feature         qw(switch);
use utf8;

use Carp;
use Narvalo::Bookkeeping::Utils     qw(is_after);
use XML::SAX::ParserFactory;
{
    my $result = {};
    # Runtime options
    my $end_ymd;
    my $type;
    # XML states
    my $_in_date    = 0;
    my $_in_amount  = 0;
    my $_in_actor   = 0;
    # Temporary variables
    my $_bank       = q{};
    my $_account    = q{};
    my $_date       = q{};
    my $_amount     = 0;
    my $_sign       = -1;
    my $_actor      = q{};
    my $_bypass     = 0;

    sub new {
        bless \do{ my $anon_scalar }, $_[0];
    }

    sub parse {
        my($self, $_xml_, $_cnf_) = @_;

        $type    = $_cnf_->{type}       if $_cnf_->{type};
        $end_ymd = $_cnf_->{end_ymd}    if $_cnf_->{end_ymd};

        #$XML::SAX::ParserPackage = q{XML::LibXML::SAX};
        my $parser  = XML::SAX::ParserFactory->parser(Handler => $self);
        $parser->parse_uri($_xml_);
    }

    sub result {
        return $result;
    }

    sub start_element {
        my($self, $_props_) = @_;

        given ($_props_->{Name}) {
            when ('Transaction') {
                $_date   = q{};
                $_amount = 0;
                $_sign   = -1;
                $_actor  = q{};

                my $keep;

                if ($_props_->{Attributes}->{'{}cleared'}) {
                    $keep = 0;
                }
                else {
                    my $is_delayed = $_props_->{Attributes}->{'{}delayed'};

                    given ($type) {
                        when ('CASH')    { $keep = !$is_delayed; }
                        when ('DELAYED') { $keep = $is_delayed; }
                        default          { $keep = 1; }
                    }
                }

                $_bypass = !$keep;
            }

            when ('Date')       { $_in_date     = 1; }
            when ('Amount')     { $_in_amount   = 1; }
            when ('Payee')      { $_in_actor    = 1; }
            when ('Withdrawal') { $_actor       = q{Retrait d'espèces}; }
            when ('Transfer')   { $_actor       = 'Transfert'; }

            when ('Payer')      { $_sign = 1; $_in_actor = 1; }
            when ('Interest')   { $_sign = 1; $_actor = 'Intérêts'; }
            when ('Deposit')    { $_sign = 1; $_actor = 'Dépôt'; }

            when ('Bank') {
                $_bank = $_props_->{Attributes}->{'{}name'}->{Value};
            }
            when ('Account') {
                $_account = $_bank
                . ' (' . $_props_->{Attributes}->{'{}name'}->{Value} . ')';
            }
        }
    }

    sub end_element {
        my($self, $_props_) = @_;

        given ($_props_->{Name}) {
            when ('Transaction') {
                return if $_bypass;

                my $amount = $_sign * $_amount;

                push @{ $result->{$_account} }, [$_date, $_actor, $amount];
            }
            when ('Date')       { $_in_date = 0; }
            when ('Amount')     { $_in_amount = 0; }
            when ('Payee')      { $_in_actor = 0; }
            when ('Payer')      { $_in_actor = 0; }
        }
    }

    sub characters {
        my($self, $_props_) = @_;

        return if $_bypass;

        my $data = $_props_->{Data};

        if ($_in_date) {
            $_bypass = $end_ymd && is_after($data, $end_ymd);

            $_date = $data;
        }
        elsif ($_in_amount) {
            $_amount = $data;
        }
        elsif ($_in_actor) {
            $_actor .= $data;
        }
    }
}

1;

__END__
