$|++;

use strict;
use warnings;

BEGIN {
    use FindBin     qw($Bin);
    use lib         qq{$Bin/../lib};
}

binmode(STDOUT, ':utf8');

use File::Spec::Functions   qw(catfile);
use Narvalo::Geo::Worker;

MAIN:
{
    my $file = catfile($Bin, '..', 'etc', 'geo.yml');

    Narvalo::Geo::Worker->new(yml_file => $file)->run();
}

__END__
