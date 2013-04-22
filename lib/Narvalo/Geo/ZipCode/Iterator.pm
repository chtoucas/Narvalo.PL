package Narvalo::Geo::ZipCode::Iterator;

use utf8;

use YAML::XS                qw(Load);
use Narvalo::Geo::ZipCode;
use Narvalo::Geo::Iterator;
{
    use Moose;

    with 'Narvalo::Geo::Iterator';

    has '+_ident' => (
        builder => '_empty_ident',
    );
#    has 'fields_size' => (
#        is          => 'ro',
#        isa         => 'Int',
#        lazy_build  => 1,
#        init_arg    => undef,
#    );

    sub _empty_ident { q{} }

    sub mk_item {
        return Narvalo::Geo::ZipCode->new($_[1]);
    }

    sub _build_filemode {
        # the file is in utf8
        return $^O eq 'MSWin32' ? q{<:utf8} : q{<:mmap:utf8};
    }

    sub _build_spec {
        my $yml = do { local $/; <DATA> };
        utf8::encode($yml);
        return Load($yml);
    }

#    sub _build_fields_size {
#        scalar shift->spec;
#    }

    around 'mk_args' => sub {
        my($orig, $self, $line) = @_;

# XXX use FIELD_SEP
        $line .= q{-1} if $line =~ m{\t\z}xms;  # No last field

        return $self->$orig($line);
    };

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__DATA__
---
- country_code:                 # iso country code, 2 characters
- postal_code:      zip_code    # postal code: varchar(10)
- place_name:       dirty_name  # place name: varchar(180)
- admin_nameA:                  # 1. order subdivision (state) varchar(100)
- admin_codeA:                  # 1. order subdivision (state) varchar(20)
- admin_nameB:                  # 2. order subdivision (county/province) varchar(100)
- admin_codeB:      department  # 2. order subdivision (county/province) varchar(20)
- admin_nameC:                  # 3. order subdivision (community) varchar(100)
- latitude:         latitude    # estimated latitude (wgs84)
- longitude:        longitude   # estimated longitude (wgs84)
- accuracy:         accuracy    # accuracy of lat/lng from 1=estimated to 6=centroid
