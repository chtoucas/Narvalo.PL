package Narvalo::Geo::City::Iterator;

use utf8;

use YAML::XS                qw(Load);
use Narvalo::Geo::City;
use Narvalo::Geo::Iterator;
{
    use Moose;

    with 'Narvalo::Geo::Iterator';

    sub mk_item {
        return Narvalo::Geo::City->new($_[1]);
    }

    sub _build_filemode {
        # the file is in windows native format: crlf and cp1252
        return $^O eq 'MSWin32'
             ? qq{<:crlf:encoding(cp1252)}
             : qq{<:mmap:crlf:encoding(cp1252)};
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
- ACTUAL:       status      # Code actualité de la commune
- CHEFLIEU:                 # Chef-lieu de canton, d'arrondissement, de département, de région
- CDC:                      # Découpage de la commune en cantons
- RANG:                     # Nombre de fractions cantonales + 1 de la commune lorsqu'elle est multicantonale
- REG:                      # Code région
- DEP:          department  # Code département
- COM:          code        # Code commune
- AR:                       # Code arrondissement
- CT:                       # Code canton
- MODIF:                    # Indicateur de modification subie par la commune
- POLE:                     # Code de la commune pôle de la commune fusionnée
- TNCC:         qprefix     # Type de nom en clair
- ARTMAJ:                   # Article (majuscules)
- NCC:                      # Nom en clair (majuscules)
- ARTMIN:                   # Article (typographie riche)
- NCCENR:       qname       # Nom en clair (typographie riche)
- ARTICLCT:                 # Article (canton)
- NCCCT:                    # Nom en clair du canton (typographie riche)
