package Narvalo::Hsbc::Transaction::Iterator;

use feature qw(switch);

use Carp;
use Date::Calc      qw(Days_in_Month);
use List::Util      qw(min);
{
    my $VERSION        = 'TABLE_V5';
    my $MIN_FIELDS_NBR = 26;

    my @FIELDS         = split /\s+/xms, do { local $/; <DATA> };
    my $FIELD_SEP      = qq{\t};
    my $IDENT_LINE     = join($FIELD_SEP, @FIELDS);
    my %FIELD_POS      = map { $FIELDS[$_] => $_ } 0...$#FIELDS;
    # Beware, sometimes there is no eol character
    my $EOL            = qr{\s*(?:\r?\n)?\z}xms;
    my $AMOUNT         = qr{\A(\d+)(\d{2})\z}xms;
    my $DATE_YMD       = qr{\A(\d{4})(\d{2})(\d{2})\z}xms;
    my $DATE_YM        = qr{\A(\d{4})(\d{2})\z}xms;
    my $INFO           = qr{\ACARD_COUNTRY=(\w+)(?:,IP_COUNTRY=(\w+))?\z}xms;

    use Moose;

    has file => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
    );
    has fh => (
        is          => 'ro',
        isa         => 'FileHandle',
        lazy_build  => 1,
        init_arg    => undef,
    );

    sub BUILD {
        my $fh = shift->fh;
        # Check title line
        (my $title = <$fh>) =~ s{$EOL}{}xms;
        my(undef, $company, $timestamp, $version) = split $FIELD_SEP, $title;
        croak "Unhandled version: $version" if $version ne $VERSION;
        # Check ident line
        (my $ident = <$fh>) =~ s{$EOL}{}xms;
        croak "Unrecognized format for ident line" if $ident ne $IDENT_LINE;
    }

    sub DEMOLISH {
        my $self = shift;
        my $file = $self->file;
        close $self->fh or carp qq{Can't close '$file': $!};
        return;
    }

    sub _build_fh {
        my $file = shift->file;
        open my $fh, '<', $file or croak qq{Can't open '$file': $!};
        return $fh;
    }

    sub next {
        my $self = shift;
        my $fh = $self->fh;
        my $line = <$fh>;

        return unless defined $line;

        $line =~ s{$EOL}{}xms;

        my @transaction = split $FIELD_SEP, $line;

        carp $self->file . " - No transaction id" and $self->next()
            unless my $id = $transaction[$FIELD_POS{TRANSACTION_ID}];
        carp "$id - Not enough fields: " . $#transaction and $self->next()
            if $#transaction < $MIN_FIELDS_NBR;

        my $fields_nbr = min($#FIELDS, $#transaction);
        my %transaction;

        foreach (0...$fields_nbr) {
            my $key = $FIELDS[$_];
            my $val = _val($id, $key, $transaction[$_]);
            $transaction{$key} = $val unless $val eq q{};
        }

        return \%transaction;
    }

    sub _val {
        my($id, $key, $val) = @_;

        return q{} if $val eq q{};

        my $realval = undef;

        given ($key) {
            when (['PAYMENT_DATE', 'CAPTURE_DATE']) {
                if ($val =~ $DATE_YMD) {
                    $realval = qq{$1-$2-$3};
                }
            }
            when (['ORIGIN_AMOUNT', 'AMOUNT']) {
                if ($val eq '0') {
                    $realval = q{};
                }
                elsif ($val =~ $AMOUNT) {
                    $realval = qq{$1,$2};
                }
            }
            when ('CARD_VALIDITY') {
                if ($val =~ $DATE_YM) {
                    $realval = qq{$1-$2-} . Days_in_Month($1, $2);
                }
            }
#            when ('COMPLEMENTARY_INFO') {
#                if ($val =~ $INFO) {
#                    $realval  = qq{<CARD_COUNTRY>$1</CARD_COUNTRY>};
#                    $realval .= qq{<IP_COUNTRY>$2</IP_COUNTRY>} if $2;
#                }
#            }
            default {
                $realval = $val;
            }
        }

        carp "$id - Unhandle property value: $key=$val"
            unless defined $realval;

        return defined $realval ? $realval : q{};
    }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__DATA__
ENTETE	TRANSACTION_ID	MERCHANT_ID	PAYMENT_MEANS	ORIGIN_AMOUNT	AMOUNT	CURRENCY_CODE	PAYMENT_DATE	PAYMENT_TIME	CARD_VALIDITY	CARD_TYPE	CARD_NUMBER	RESPONSE_CODE	CVV_RESPONSE_CODE	COMPLEMENTARY_CODE	CERTIFICATE	AUTHORIZATION_ID	CAPTURE_DATE	TRANSACTION_STATUS	RETURN_CONTEXT	AUTORESPONSE_STATUS	ORDER_ID	CUSTOMER_ID	CUSTOMER_IP_ADDRESS	ACCOUNT_SERIAL	SESSION_ID	TRANSACTION_CONDITION	CAVV_UCAF	COMPLEMENTARY_INFO	BANK_RESPONSE_CODE
