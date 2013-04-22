package Narvalo::Geo::ZipCode::XmlExporter;

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
  [%- FILTER replace('>\s<', '><') %]
  [%- FILTER collapse %]
  <item zip="[% elt.zip_code %]"
        dept="[% elt.department %]">
    <qname qprefix="[% elt.qprefix %]">[% elt.qname %]</qname>
    <geo latitude="[% elt.latitude %]" longitude="[% elt.longitude %]"
         accuracy="[% elt.accuracy %]"/>
  </item>
  [%- END %]
  [%- END %]
[% END -%]
</list>
