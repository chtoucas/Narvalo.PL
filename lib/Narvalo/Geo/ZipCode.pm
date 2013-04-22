package Narvalo::Geo::ZipCode;

use Narvalo::Geo::Utils;
use Narvalo::Types;
{
    use Moose;

    has dirty_name => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
        trigger     => \&_dirty_name_set,
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
    has zip_code => (
        is          => 'ro',
        isa         => 'ZipCode',
        required    => 1,
    );
    has department => (
        is          => 'ro',
        isa         => 'Department',
        required    => 1,
    );
    has accuracy => (
        is          => 'ro',
        isa         => 'Int',
        required    => 1,
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
