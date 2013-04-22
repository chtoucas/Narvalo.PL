package Narvalo::Geo::Iterator;

use Carp;
{
    my $FIELD_SEP = qq{\t};

    use Moose::Role;

    requires 'mk_item';
    requires '_build_filemode';
    requires '_build_spec';

    has file => (
        is          => 'ro',
        isa         => 'Str',
        required    => 1,
    );

    has filemode => (
        is          => 'ro',
        isa         => 'Str',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has spec => (
        is          => 'ro',
        isa         => 'ArrayRef',
        lazy_build  => 1,
        init_arg    => undef,
    );

    has fh => (
        is          => 'ro',
        isa         => 'FileHandle',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has _ident => (
        is          => 'ro',
        isa         => 'Str',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has _positions => (
        is          => 'ro',
        isa         => 'ArrayRef',
        lazy_build  => 1,
        init_arg    => undef,
    );
    has _fields => (
        is          => 'ro',
        isa         => 'ArrayRef',
        lazy_build  => 1,
        init_arg    => undef,
    );

    sub BUILD {
        croak "Unrecognized format for ident line" unless shift->cmp_ident();
    }

    sub DEMOLISH {
        my $self = shift;
        return unless $self->fh;
        my $file = $self->file;
        close $self->fh or carp qq{Can't close '$file': $!};
        return;
    }

    sub _build_fh {
        my $self = shift;
        my $file = $self->file;
        open my $fh, $self->filemode, $file
            or croak qq{Can't open '$file': $!};
        return $fh;
    }

    sub _build__ident {
        join(q{}, map {keys %$_} @{shift->spec});
    }

    sub _build__fields {
        my $spec = shift->spec;
        [ map { values %{ $spec->[$_] } } 0..$#$spec ]
    }

    sub _build__positions  {
        my $spec = shift->spec;
        [ grep { (values %{ $spec->[$_] })[-1] } 0..$#$spec ]
    }

    sub cmp_ident {
        my $self = shift;
        return 1 unless $self->_ident;
        # Check ident line
        my $fh = $self->fh;
        my $ident = <$fh>;
        $ident =~ s{$FIELD_SEP}{}g;
        chomp $ident;
        return $ident eq $self->_ident;
    }

    sub next {
        my $self = shift;
        my $fh = $self->fh;
        my $line = <$fh>;

        return unless defined $line;

        chomp $line;

        my $item = eval { $self->mk_item( $self->mk_args($line) ) };

        carp "Invalid record at line $." and return $self->next() if $@;

        return $item;
    }

    sub mk_args {
        my($self, $line) = @_;
        my @line = split $FIELD_SEP, $line;
        my($fields, $positions) = ($self->_fields, $self->_positions);
        return { map { $fields->[$_] => $line[$_] } @$positions };
    }

    no Moose;
}

1;

__END__
