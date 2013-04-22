package Narvalo::Geo::Department::XmlExporter;

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
  <item department="[% elt.department %]"
        region="[% elt.region %]"
        capital="[% elt.capital %]">
    <qname qprefix="[% elt.qprefix %]">[% elt.qname %]</qname>
  </item>
  [%- END %]
  [%- END %]
[% END -%]
</list>
