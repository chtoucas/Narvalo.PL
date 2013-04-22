BEGIN {
    use constant {
        DEV   => 1,     # You do not want to change this
        BENCH => 0,     # Itou!
        DIAG  => 1,     # Enable Perl diagnostics through DBG
        VERB  => 2,     # Turn on verbose messages through DBG
        DUMP  => 4,     # Dump data using Data::Dumper through DBG
        DBG   => 4,
        # For debugging purpose only
        # 0 (for no debug) or any BitOR combination
        # of DIAG, VERB and DUMP
    };

    eval "use lib '../lib'"       if DEV;
    eval "use Benchmark qw(:all :hireswallclock)" if BENCH;
    eval "use diagnostics"        if DBG & DIAG;
    eval "use Data::Dumper"       if DBG & DUMP;

    sub _dbg ($@) {
        my $_level_ = shift;
        return unless DBG & $_level_;
        if ($_level_ == VERB) {
            print STDERR "*** DEBUG\n", @_, "\n";
        } elsif ($_level_ == DUMP) {
            print STDERR "*** DUMP\n";
            print STDERR Data::Dumper->Dump([$_[1]], [($_[0])]);
        }
    }
}

END {
    print STDERR "\n*** DEVEL VERSION\n"  if DEV;
    print STDERR "*** DEBUG ENABLED\n"    if DBG;
}

1;
