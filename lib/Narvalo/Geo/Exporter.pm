package Narvalo::Geo::Exporter;

use Carp;
use Template;
use Template::Directive;
{
    use Moose::Role;

    requires '_build_tpl';

    has file => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
    );
    has tpl => (
        is          => 'ro',
        isa         => 'ScalarRef',
        lazy_build  => 1,
        init_arg    => undef,
    );

    sub export {
        my($self, $it) = @_;

        local $Template::Directive::WHILE_MAX = 200000;

        my $tt = Template->new() || croak Template->error();
        my $file = $self->file;

        open my $fh, '+>:utf8', $file or carp qq{Can't open '$file': $!};
        $tt->process($self->tpl, {it => $it}, $fh) || croak $tt->error();
        close $fh or carp qq{Can't close '$file': $!};
        return;
    }

    no Moose;
}

1;

