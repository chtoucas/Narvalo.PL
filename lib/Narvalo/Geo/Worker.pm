package Narvalo::Geo::Worker;

use Carp;
use File::Spec::Functions   qw(catfile);
use Narvalo::Worker;
{
    my %DELEGATES = (
        cities      => ['Narvalo::Geo::City::Iterator',
                        'Narvalo::Geo::City::XmlExporter'],
        departments => ['Narvalo::Geo::Department::Iterator',
                        'Narvalo::Geo::Department::XmlExporter'],
        geopoints   => ['Narvalo::Geo::GeoPoint::Iterator',
                        'Narvalo::Geo::GeoPoint::XmlExporter'],
        regions     => ['Narvalo::Geo::Region::Iterator',
                        'Narvalo::Geo::Region::XmlExporter'],
        zipcodes    => ['Narvalo::Geo::ZipCode::Iterator',
                        'Narvalo::Geo::ZipCode::XmlExporter'],
    );

    use Moose;

    with 'Narvalo::Worker';

    has type_map => (
        is          => 'ro',
        isa         => 'HashRef',
        lazy_build  => 1,
        init_arg    => undef,
    );

    sub run {
        my $self = shift;

        local $SIG{__WARN__} = sub { $self->logger->warn(@_); };
        local $SIG{__DIE__}  = sub { $self->logger->crit(@_); };

        $self->begin_phase('Working');

        my $files = $self->get_files();

      FILE:
        while (my($txt, $type) = each %$files) {
            $self->continue_phase();
            my $xml = qq{$type.xml};
            my $it  = $self->_mk_iterator($type, catfile($self->in_dir,  $txt));
            my $exp = $self->_mk_exporter($type, catfile($self->out_dir, $xml));
            $exp->export($it);
        }

        $self->end_phase();
    }

    sub get_files {
        my $self = shift;
        my $in_dir = $self->in_dir;

        opendir DIR, $in_dir or croak qq{Can't open '$in_dir': $!};
        my %files = map  { $_ => $self->type_map->{$_} }
                    grep { exists $DELEGATES{ $self->type_map->{$_} } }
                    grep { exists $self->type_map->{$_} }
                    sort grep m{\.txt$}i, readdir(DIR);
        closedir DIR or carp qq{Can't close '$in_dir': $!};

        return \%files;
    }

    sub _build_subdir   { shift->_local_conf()->{subdir} }
    sub _build_type_map { shift->_local_conf()->{type_map} }
    sub _local_conf     { shift->conf->{geo} }
    sub _mk_iterator    { shift->_mk_obj(0, @_) }
    sub _mk_exporter    { shift->_mk_obj(1, @_) }

    sub _mk_obj {
        my($self, $obj_t, $geo_t, $file) = @_;
        my $class = $DELEGATES{$geo_t}[$obj_t];
        eval "require $class;";
        croak qq{Unable to load '$class'} if $@;
        return $class->new(file => $file);
    }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__END__
