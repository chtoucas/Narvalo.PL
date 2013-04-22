package Mail::Pine::Pinerc;

=head1 NAME

B<Mail::Pine::Pinerc> - Perl module to parse Pine configuration file

=head1 SYNOPSIS

    use Mail::Pine::Pinerc;
    my $pinerc = Mail::Pine::Pinerc->new();
    $pinerc->parse();

=head1 DESCRIPTION

The Mail::Pine::Pinerc provides read-only access to your pinerc.

=cut

use strict;
use warnings;

use base qw(Mail::Pine);

use Carp;
use Symbol                      qw(gensym);
use File::Spec::Functions       qw(catfile);
use Mail::Pine::Pinerc::Option;

### Constructor

sub new {
    my($class, %_cnfs_) = @_;
    bless {
        PATH => $_cnfs_{Path}   || catfile($ENV{HOME}, '.pinerc'),
        OPTS => $_cnfs_{Opts}   || [],
        DATA => {}
    }, $class;
}

### Public Methods

sub option { $_[0]->{DATA}{ $_[1] }; }

sub options {
    if ($_[1]) {
        my %opts = map { $_ => $_[0]->{DATA}{$_} } $_[1];
        return \%opts;
    }
    else {
        return $_[0]->{DATA};
    }
}

sub parse {
    my($self) = @_;

    croak __PACKAGE__, "::parse() -- Your pinerc is not there: $self->{PATH}"
    unless -e $self->{PATH};

    my %opts;
    @opts{ @{ $self->{OPTS} } } = ();

    my $name   = '';
    my $pinerc = gensym();

    open($pinerc, "< $self->{PATH}")
        or croak __PACKAGE__, "::parse() -- Can't read $self->{PATH}: $!";

    LINE:
    while (<$pinerc>) {
        next LINE if m/^#/;

        # !!! WARNING !!!
        # Do not remove leading whitespaces, they are important in order to
        # separate single-valued from multi-valued options
        chomp;
        s/\s+$//;

        next LINE unless length;

        if (s/^\s+//) {
            # Middle or end of a multi-valued option

            next LINE unless $name;

            if (s/,$//) {
                # To be continued
                push @{ $self->{DATA}{$name} }, $_;
            }
            else {
                push @{ $self->{DATA}{$name} }, $_;

                last LINE if %opts && keys %opts == keys %{ $self->{DATA} };
            }
        }
        elsif (s/,$//) {
            # Start of a multi-valued option

            m/^(.+?)=(.*)$/;
            if (%opts && not exists $opts{$1}) { $name = ''; next LINE; }
            $name = $1;
            push @{ $self->{DATA}{$name} }, $2;
        }
        else {
            # One-line option (multi-valued or not)

            m/^(.+?)=(.*)$/;

            next LINE if %opts && not exists $opts{$1};

            if (Mail::Pine::Pinerc::Option::is_multivalued($1)) {
                # The option is multi-valued
                if ($2) {
                    push @{ $self->{DATA}{$1} }, $2;
                }
                else {
                    $self->{DATA}{$1} = [];
                }
            }
            else {
                # The option is single-valued
                $self->{DATA}{$1} = $2;
            }

            last LINE if %opts && keys %opts == keys %{ $self->{DATA} };
        }
    }

    close($pinerc)
        or carp __PACKAGE__, "::parse() -- Can't close $self->{PATH}: $!";

    1;
}

1;

__END__

## EOF
