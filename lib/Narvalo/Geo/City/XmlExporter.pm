package Narvalo::Geo::City::XmlExporter;

use Narvalo::Geo::Exporter;
{
    use Moose;

    with 'Narvalo::Geo::Exporter';

    sub _build_tpl { \do { local $/; <DATA> }; }

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

__DATA__
<?xml version="1.0" encoding="utf-8"?>
<list>
[% WHILE (elt = it.next) %]
  [%- NEXT IF elt.status == 6 %][%# Fraction communale %]
  [%- FILTER replace('>\s<', '><') %]
  [%- FILTER collapse %]
  <item dept="[% elt.department %]">
    <qname qprefix="[% elt.qprefix %]">[% elt.qname %]</qname>
    <insee code="[% elt.insee_code %]" status="[% elt.status %]">
    </insee>
  </item>
  [%- END %]
  [%- END %]
[% END -%]
</list>
