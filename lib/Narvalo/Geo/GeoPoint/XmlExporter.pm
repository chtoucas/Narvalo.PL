package Narvalo::Geo::GeoPoint::XmlExporter;

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
  [%- NEXT IF !elt.is_ident %][%# Non identifié %]
  [%- FILTER replace('>\s<', '><') %]
  [%- FILTER collapse %]
  <item [% IF elt.zip_code %]zip="[% elt.zip_code %]"[% END %]
        [% IF elt.department %]dept="[% elt.department %]"[% END %]>
    <qname qprefix="[% elt.qprefix %]">[% elt.qname %]</qname>
    [% IF elt.alt_names.size %]
    <altnames>
      [%- FOREACH name IN elt.alt_names %]<alias>[% name %]</alias>[% END %]
    </altnames>
    [% END %]
    <geo latitude="[% elt.latitude %]" longitude="[% elt.longitude %]"/>
    <geonames geoid="[% elt.geoid %]"
              last_modification_date="[% elt.last_modification_date %]"/>
    [% IF elt.insee_code %]<insee code="[% elt.insee_code %]"/>[% END %]
  </item>
  [%- END %]
  [%- END %]
[% END -%]
</list>
