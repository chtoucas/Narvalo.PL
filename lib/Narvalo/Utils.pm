package Narvalo::Utils;

use strict;
use warnings;

use base qw(Narvalo);

use Carp;
use Perl6::Export::Attrs;
#use YAML::XS                qw(Load);
use YAML::Tiny              qw(Load);
{
    sub get_config :Export(:DEFAULT) {
        my($file) = @_;

        open my $fh, '<:utf8', $file or croak qq{Can't open '$file': $!};
        my $yaml = do { local $/; <$fh> };
        close $fh or croak qq{Can't close '$file' after reading: $!};

        utf8::encode($yaml);

        return Load($yaml);
    }

    sub begin_phase :Export(:DEFAULT) {
        print {*STDERR} qq{$_[0]...};
        return;
    }

    sub continue_phase :Export(:DEFAULT) {
        print {*STDERR}  q{.};
        return;
    }

    sub mark_phase :Export(:DEFAULT) {
        print {*STDERR}  qq{$_[0]};
        return;
    }

    sub end_phase :Export(:DEFAULT) {
        print {*STDERR} qq{done\n};
        return;
    }
}

1;
