# This -*- perl -*- script writes the Makefile for Mail::Pine

use 5.006;
use strict;
use ExtUtils::MakeMaker qw(WriteMakefile prompt);
use Config              qw(%Config);

#my @programs = qw(pinestats);
#
#if (@programs) {
#    print <<EOT;
#
#This package comes with some sample programs that I can try to install.
#
#EOT
#
#    my @tmp;
#    for (@programs) {
#       if (prompt("Do you want to install $_?", "y") =~ /^y/) {
#           push(@tmp, $_);
#       }
#    }
#    @programs = @tmp;
#}

WriteMakefile(
    'NAME'          => 'Mail::Pine',
    'VERSION_FROM'  => 'lib/Mail/Pine.pm',
    #'EXE_FILES'            => [ map "bin/$_", @programs ],
    'PREREQ_PM'     => {},
    (
        $] >= 5.005 ?
        (
            ABSTRACT_FROM => 'lib/Mail/Pine.pm',
            AUTHOR => 'Tran Ngoc Bich <chtoucas (at) narvalo (dot) org>'
        ) :
        ()
    ),
);
