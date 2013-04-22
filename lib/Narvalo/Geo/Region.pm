package Narvalo::Geo::Region;

use Narvalo::Types;
{
    use Moose;

    has region => (
        is          => 'ro',
        isa         => 'Region',
        required    => 1,
    );
    has capital => (
        is          => 'ro',
        isa         => 'InseeCode',
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

    has name => (
        is          => 'ro',
        isa         => 'Str',
        lazy_build  => 1,
        init_arg    => undef,
    );

    sub _build_name { shift->qname; }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
