package Narvalo::Log;

use Carp;
use DateTime;
use File::Spec::Functions   qw(catfile);
{
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
    has start_time  => (
        is          => 'ro',
        isa         => 'DateTime',
        default     => sub { return DateTime->now; },
        init_arg    => undef,
    );

    sub DEMOLISH {
        my $self = shift;
        my $file = $self->file;
        close $self->fh or carp qq{Can't close '$file': $!};
        return;
    }

    sub _build_fh {
        my $file = shift->file;
        open my $fh, '+>>:utf8', $file or croak qq{Can't open '$file': $!};
        return $fh;
    }

    sub start {
        my $self = shift;
        $self->info(qq{Start: } . $self->start_time);
        return;
    }

    sub end {
        my $self = shift;
        my $now = DateTime->now;
        my $diff = $now - $self->start_time;
        $self->info(
              qq{End: $now. Elapsed time: }
            . $diff->minutes() . q{ mins }
            . $diff->seconds() . q{ secs});
        return;
    }

    sub info { shift->_write(q{[info]}, @_);     return; }
    sub warn { shift->_write(q{[warn] ***}, @_); return; }
    sub crit { shift->_write(q{[crit] !!!}, @_); return; }

    sub _write {
        my $self = shift;
        my $msg = join(q{ }, @_);
        chomp $msg;
        syswrite $self->fh, qq{$msg\n};
        return;
    }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
