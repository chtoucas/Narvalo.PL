package Narvalo::Geo::GeoPoint::Iterator;

use utf8;

use YAML::XS                qw(Load);
use Narvalo::Geo::GeoPoint;
use Narvalo::Geo::Iterator;
{
    use Moose;

    with 'Narvalo::Geo::Iterator';

    has '+_ident' => (
        builder => '_empty_ident',
    );

    sub _empty_ident { q{} }

    sub mk_item {
        return Narvalo::Geo::GeoPoint->new($_[1]);
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

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__DATA__
---
- geonameid:        geoid       # integer id of record in geonames database
- name:	            dirty_name  # name of geographical point (utf8) varchar(200)
- asciiname:       	        # name of geographical point in plain ascii characters, varchar(200)
- aliases:	    aliases     # alternatenames, comma separated varchar(4000) (varchar(5000) for SQL Server)
- latitude:	    latitude    # latitude in decimal degrees (wgs84)
- longitude:	    longitude   # longitude in decimal degrees (wgs84)
- feature_class:                # see http://www.geonames.org/export/codes.html, char(1)
- feature_code:	                # see http://www.geonames.org/export/codes.html, varchar(10)
- country_code:	                # ISO-3166 2-letter country code, 2 characters
- cc2:	                        # alternate country codes, comma separated, ISO-3166 2-letter country code, 60 characters
- admin1_code:	                # fipscode (subject to change to iso code), isocode for the us and ch, see file admin1Codes.txt for display names of this code; varchar(20)
- department:	    department  # code for the second administrative division, a county in the US, see file admin2Codes.txt; varchar(80)
- admin3_code:	                # code for third level administrative division, varchar(20)
- insee_code:       insee_code	# code for fourth level administrative division, varchar(20)
- population:	                # bigint (4 byte int)
- elevation:	                # in meters, integer
- gtopo30:	                # average elevation of 30'x30' (ca 900mx900m) area in meters, integer
- timezone:	                # the timezone id (see file timeZone.txt)
- last_modification_day:    last_modification_day	#
