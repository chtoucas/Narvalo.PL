package Narvalo::Geo::City;

use Narvalo::Geo::Utils;
use Narvalo::Types;
{
    use Moose;

    has status => (
        is          => 'ro',
        isa         => 'Int',
        required    => 1,
    );
    has department => (
        is          => 'ro',
        isa         => 'Department',
        required    => 1,
    );
    has code => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
    );
    has qprefix => (
        is          => 'ro',
        isa         => 'Int',
        required    => 1,
    );
    has qname => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
    );

    has insee_code => (
        is          => 'ro',
        isa         => 'InseeCode',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has name => (
        is          => 'ro',
        isa         => 'Str',
        lazy_build  => 1,
        init_arg    => undef,
    );

    sub _build_insee_code {
        my $self = shift;
        return $self->department . $self->code;
    }

    sub _build_name {
        my $self = shift;
        return format_name($self->qprefix, $self->qname);
    }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
