package Narvalo::Geo::Region::Iterator;

use utf8;

use YAML::XS                qw(Load);
use Narvalo::Geo::Region;
use Narvalo::Geo::Iterator;
{
    use Moose;

    with 'Narvalo::Geo::Iterator';

    sub mk_item {
        return Narvalo::Geo::Region->new($_[1]);
    }

    sub _build_filemode {
        # the file is in windows native format: crlf and cp1252
        return qq{<:crlf:encoding(cp1252)};
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
- REGION:       region      # Code région
- CHEFLIEU:     capital     # Code de la commune chef-lieu
- TNCC:         qprefix     # Type de nom en clair
- NCC:                      # Libellé en lettres majuscules
- NCCENR:       qname       # Libellé enrichi
