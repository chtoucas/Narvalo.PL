package Narvalo::Bookkeeping::SVG;

use strict;
use vars qw($AUTOLOAD);

use Carp;
use POSIX;
use Template;

# set up TT object
my %config = (
    POST_CHOMP      => 1,
    PRE_CHOMP       => 1,
    TRIM            => 1,
    INCLUDE_PATH    => '/',
);
my $tt = Template->new( \%config );

sub new {
    my($proto, $conf) = @_;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    if ($self->can('_set_defaults')) {
        # Populate with local defaults
        $self->_set_defaults();
    }
    else {
        croak "$class should have a _set_defaults method";
    }

    # overwrite defaults with user options
    while (my ($key,$value) = each %{$conf}) {
        $self->{config}->{$key} = $value;
    }

    # Allow the inheriting modules to do checks
    if ($self->can('_init')) {
        $self->_init();
    }

    return $self;
}

sub add_data {
    my($self, $conf) = @_;

    # create an array
    unless (defined $self->{'data'}) {
        my @data;
        $self->{'data'} = \@data;
    }

    croak 'no fields array ref'
    unless defined $self->{'config'}->{'fields'}
    && ref($self->{'config'}->{'fields'}) eq 'ARRAY';

    if (defined $conf->{'data'} && ref($conf->{'data'}) eq 'ARRAY') {
        my %new_data;
        @new_data{@{$self->{'config'}->{'fields'}}} = @{$conf->{'data'}};
        my %store = (
            'data' => \%new_data,
        );
        $store{'title'} = $conf->{'title'} if defined $conf->{'title'};
        push (@{$self->{'data'}},\%store);

        return 1;
    }

    return undef;
}

sub clear_data {
    my $self = shift;
    my @data;

    $self->{'data'} = \@data;
}

sub burn {
    my $self = shift;

    # Check we have at least one data value
    croak "No data available"
    unless scalar(@{$self->{'data'}}) > 0;

    # perform any calculations prior to burn
    $self->calculations() if $self->can('calculations');

    croak ref($self) . ' must have a get_template method.'
    unless $self->can('get_template');

    my $template = $self->get_template();

    my %vals = (
        'data'      => $self->{'data'},     # the data
        'config'    => $self->{'config'},   # the configuration
        'calc'      => $self->{'calc'},     # the calculated values
        'sin'       => \&_sin_it,
        'cos'       => \&_cos_it,
    );

    # euu - hack!! - maybe should just be a method
    $self->{sin} = \&_sin_it;
    $self->{cos} = \&_cos_it;

    my $file;
    my $template_responce = $tt->process( \$template, \%vals, \$file );

    if ($tt->error()) {
        croak "Template error: " . $tt->error . "\n" if $tt->error;
    }

    # compress if required
    if ($self->{config}->{compress}) {
        if (eval "require Compress::Zlib") {
            return Compress::Zlib::memGzip($file) ;

        }
        else {
            $file .= "<!-- Compress::Zlib not available for SVGZ:$@ -->";
        }
    }

    return $file;
}

sub _sin_it {
    return sin(shift);
}

sub _cos_it {
    return cos(shift);
}

sub _range_calc () {
    my $self  = shift;
    my $range = shift;

    my($max, $division);
    my $count = 0;
    my $value = $range;

    if ($value == 0) {
        # Can't do much really
        $division = 0.2;
        $max = 1;
        $count = 1;

        return ($max, $division, $count);
    }

    if ($value < 1) {
        while ($value < 1) {
            $value *= 10;
            $count++;
        }
        $division = 1;
        while ($count--) {
            $division /= 10;
        }
        $max = ceil($range / $division) * $division;
    }
    else {
        while ($value > 10) {
            $value /= 10;
            $count++;
        }
        $division = 1;
        while ($count--) {
            $division *= 10;
        }
        $max = ceil($range / $division) * $division;
    }

    if (int($max / $division) <= 2) {
        $division /= 5;
        $max = ceil($range / $division) * $division;
    }
    elsif (int($max / $division) <= 5) {
        $division /= 2;
        $max = ceil($range / $division) * $division;
    }

    if ($division >= 1) {
        $count = 0;
    }
    else {
        $count = length($division) - 2;
    }

    return ($max, $division, $count);
}

# Returns true if config value exists, is defined and not ''
sub _is_valid_config() {
    my($self,$name) = @_;

    return ((exists $self->{config}->{$name}) && (defined $self->{config}->{$name}) && ($self->{config}->{$name} ne ''));
}

## AUTOLOAD FOR CONFIG editing

sub AUTOLOAD {
    my $name = $AUTOLOAD;
    $name =~ s/.*://;

    croak "No object supplied" unless $_[0];

    if (defined $_[0]->{'config'}->{$name}) {
        if (defined $_[1]) {
            # set the value
            $_[0]->{'config'}->{$name} = $_[1];
        }

        return defined $_[0]->{'config'}->{$name}
        ? $_[0]->{'config'}->{$name}
        : undef;
    }
    else {
        croak "Method: $name can not be used with " . ref($_[0]);
    }
}

# As we have AUTOLOAD we need this
sub DESTROY { }

1;
