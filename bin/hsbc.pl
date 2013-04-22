$|++;

use strict;
use warnings;

BEGIN {
    use FindBin     qw($Bin);
    use lib         qq{$Bin/../lib};
}

use File::Spec::Functions   qw(catfile);
use Narvalo::Hsbc::Worker;

MAIN:
{
    my $file = catfile($Bin, '..', 'etc', 'hsbc.yml');

    Narvalo::Hsbc::Worker->new(yml_file => $file)->run();
}

__END__
