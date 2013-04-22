package Narvalo::Worker;

use Carp;
use File::Spec::Functions   qw(catfile);
use YAML::XS                qw(Load);
use Narvalo::Log;
{
    use Moose::Role;

    requires 'run';
    requires '_build_subdir';

    has yml_file => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
        trigger     => \&_yml_file_set,
    );
    has conf => (
        is          => 'ro',
        isa         => 'HashRef',
        writer      => '_set_conf',
        required    => 0,
        init_arg    => undef,
    );

    has in_dir => (
        is          => 'ro',
        isa         => 'Str',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has out_dir => (
        is          => 'ro',
        isa         => 'Str',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has subdir => (
        is          => 'ro',
        isa         => 'Str',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has logger => (
        is          => 'ro',
        isa         => 'Narvalo::Log',
        lazy_build  => 1,
        init_arg    => undef,
    );

    before 'run' => sub {
        my $self = shift;

        # Check existence of input directory
        my $in_dir = $self->in_dir;
        croak qq{Directory '$in_dir' does not exist} unless -e $in_dir;

        # Create output directory if it does not exist yet
        my $out_dir = $self->out_dir;
        unless (-e $out_dir) {
            eval { mkdir($out_dir) };
            croak qq{Unable to create '$out_dir' dir: $!} if $@;
        }

        # Create logger
        $self->logger->start();
    };

    after 'run' => sub { shift->logger->end(); };

    sub begin_phase     { print {*STDERR} qq{$_[1]...}; return; }
    sub continue_phase  { print {*STDERR}  q{.};        return; }
    sub mark_phase      { print {*STDERR} qq{$_[1]};    return; }
    sub end_phase       { print {*STDERR} qq{done\n};   return; }

    sub _yml_file_set {
        my $self = shift;
        my $file = $self->yml_file;
        open my $fh, '<:utf8', $file or croak qq{Can't open '$file': $!};
        my $yaml = do { local $/; <$fh> };
        close $fh or croak qq{Can't close '$file' after reading: $!};

        utf8::encode($yaml);

        $self->_set_conf( Load($yaml) );
    }

    sub _build_in_dir {
        my $self = shift;
        return catfile($self->conf->{working_dir}, 'in', $self->subdir);
    }

    sub _build_out_dir {
        my $self = shift;
        return catfile($self->conf->{working_dir}, 'out', $self->subdir);
    }

    sub _build_logger {
        return new Narvalo::Log(file => catfile(shift->out_dir, 'run.log'));
    }

    no Moose;
}

1;

__END__
