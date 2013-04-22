package Narvalo::Types;

use Carp;
{
    use Moose;
    use Moose::Util::TypeConstraints;

    subtype 'EmptyStr'
        => as 'Str' => where { $_ eq q{} };

    subtype 'NotEmptyStr'
        => as 'Str' => where { $_ ne q{} };

    subtype 'Region'
        => as 'Str' => where { 2 == $_ =~ tr/0-9AB//; };

    subtype 'Department'
        => as 'Str' => where { 3 >= $_ =~ tr/0-9AB//; };

    subtype 'InseeCode'
        => as 'Str' => where { 5 == $_ =~ tr/0-9AB//; };

    subtype 'ZipCode'
        => as 'Str' => where { 5 == $_ =~ tr/0-9//; };

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;
