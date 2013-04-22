package Narvalo::Geo::GeoPoint;

use Date::Tiny;
use Narvalo::Geo::Utils;
use Narvalo::Types;
{
    my $DATE = qr{\A\d{4}-\d{2}-\d{2}\z}xms;

    use Moose;
    use Moose::Util::TypeConstraints;

    has geoid => (
        is          => 'ro',
        isa         => 'Int',
        required    => 1,
    );
    has dirty_name => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
        trigger     => \&_dirty_name_set,
    );
    has aliases => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
        trigger     => \&_aliases_set,
    );
    has latitude => (
        is          => 'ro',
        isa         => 'Num',
        required    => 1,
    );
    has longitude => (
        is          => 'ro',
        isa         => 'Num',
        required    => 1,
    );
    has insee_code => (
        is          => 'ro',
        isa         => 'InseeCode | EmptyStr',
        required    => 1,
    );
    has department => (
        is          => 'ro',
        isa         => 'Department | EmptyStr',
        required    => 1,
    );
    has last_modification_day => (
        is          => 'ro',
        required    => 1,
        isa         => subtype 'Str' => where { m{$DATE} },
    );

    has name => (
        is          => 'ro',
        isa         => 'Str',
        lazy_build  => 1,
        init_arg    => undef,
    );

    has qname => (
        is          => 'ro',
        isa         => 'Str',
        writer      => '_set_qname',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has qprefix => (
        is          => 'ro',
        isa         => 'Int',
        writer      => '_set_qprefix',
        lazy_build  => 1,
        init_arg    => undef,
    );

    has zip_code => (
        is          => 'ro',
        isa         => 'ZipCode | EmptyStr',
        writer      => '_set_zip_code',
        required    => 0,
        default     => sub { q{} },
        init_arg    => undef,
    );
    has alt_names => (
        is          => 'ro',
        isa         => 'ArrayRef[Str]',
        writer      => '_set_alt_names',
        required    => 0,
        default     => sub { [] },
        init_arg    => undef,
    );
    has last_modification_date => (
        is          => 'ro',
        isa         => 'Date::Tiny',
        required    => 0,
        lazy_build  => 1,
        init_arg    => undef,
    );

    sub is_ident {
        return $_[0]->zip_code || $_[0]->insee_code;
    }

    sub is_loosely_ident {
        return $_[0]->zip_code || $_[0]->insee_code || $_[0]->department;
    }

    sub _aliases_set {
        my($self, $aliases) = @_;

        return unless $aliases;

        my @alt_names;
        if (index q{,}, $aliases) {
            @alt_names = split /,/, $aliases;
            my $candidate = $alt_names[0];
            if (length $candidate == $candidate =~ tr/0-9//) {
                $self->_set_zip_code($candidate);
                shift @alt_names;
            }
        }
        else {
            if (length $aliases == $aliases =~ tr/0-9//) {
                $self->_set_zip_code($aliases);
            }
            else {
                @alt_names = ($aliases);
            }
        }
        $self->_set_alt_names(\@alt_names) if @alt_names;
    }

    sub _build_last_modification_date {
        return Date::Tiny->from_string(shift->last_modification_day)
    }

    sub _dirty_name_set {
        my($self, $name) = @_;
        my($qprefix, $qname) = parse_dirty_name($name);
        $self->_set_qname($qname);
        $self->_set_qprefix($qprefix);
    }

    sub _build_name {
        my $self = shift;
        return format_name($self->qprefix, $self->qname);
    }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
