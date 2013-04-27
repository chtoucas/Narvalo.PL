package Narvalo::Bookkeeping::SVG::TimeSeries;

use strict;

use Carp;
use Data::Dumper;
use HTTP::Date;
use DateTime;
use POSIX;

use Narvalo::Bookkeeping::SVG;
use base qw(SVG::TT::Graph);

my $template;

sub get_template {
    my $self = shift;

    return $template if $template;

     while (<DATA>) {
         s/^\s+//;
         $template .= $_;
     }

    return $template;
}

sub _init {
    my $self = shift;
}

sub _set_defaults {
    my $self = shift;

    my @fields = ();

    my %default = (
        'fields'            => \@fields,

        'width'             => '500',
        'height'            => '300',

        'style_sheet'       => '',
        'show_data_points'  => 1,
        'show_data_values'  => 1,
        'max_time_span'     => '',

        'area_fill'         => 0,

        'show_y_labels'     => 1,
        'scale_divisions'   => '',
        'min_scale_value'   => '0',

        'stacked'           => 0,

        'show_x_labels'     => 1,
        'stagger_x_labels'  => 0,
        'rotate_x_labels'   => 0,
        'timescale_divisions'   => '',
        'x_label_format'    => '%Y-%m-%d %H:%M:%S',

        'show_x_title'      => 0,
        'x_title'           => 'X Field names',

        'show_y_title'      => 0,
        'y_title'           => 'Y Scale',

        'show_graph_title'      => 0,
        'graph_title'           => 'Graph Title',
        'show_graph_subtitle'   => 0,
        'graph_subtitle'        => 'Graph Sub Title',
        'key'                   => 0,
        'key_position'          => 'right', # bottom or right

        'dateadd'               => \&dateadd,
    );

    while (my($key,$value) = each %default) {
        $self->{config}->{$key} = $value;
    }
}

# override this so we can pre-manipulate the data
sub add_data {
    my($self, $conf) = @_;

    croak 'no data provided'
        unless (defined $conf->{'data'} && ref($conf->{'data'}) eq 'ARRAY');

    # create an array
    unless (defined $self->{'data'}) {
        my @data;
        $self->{'data'} = \@data;
    }

    # convert to sorted (by ascending time) array of [ time, value ]
    my @new_data = ();
    my($i, $time, @pair);

    $i = 0;
    while ($i < @{$conf->{'data'}}) {
        @pair = ();
        if (ref($conf->{'data'}->[$i]) eq 'ARRAY') {
            push @pair, @{$conf->{'data'}->[$i]};
            $i++;
        }
        else {
            $pair[0] = $conf->{'data'}->[$i++];
            $pair[1] = $conf->{'data'}->[$i++];
        }

        $time = str2time($pair[0]);
        # special case for time-only values
        if (   !defined $time
            && $pair[0] =~ m/^\w*(\d+:\d+:\d+)|(\d+:\d+)\w*$/
        )  {
            $time = str2time('1970-1-1 ' . $pair[0]);
        }

        unless (defined $time) {
            my $err = sprintf(
                "Series %d contains an illegal datetime value %s at sample %d.",
                scalar(@{$self->{'data'}}),
                $pair[0],
                $i/2
            );
            croak $err;
        }

        $pair[0] = $time;
        push @new_data, [@pair];
    }

    my @sorted = sort {@{$a}[0] <=> @{$b}[0]} @new_data;

    # if stacked, we accumulate the
    if ($self->{config}->{stacked} && @{$self->{'data'}}) {
        my $prev = $self->{'data'}->[@{$self->{'data'}} - 1]->{pairs};

        # check our length matches previous
        croak
            sprintf(
                "Series %d can not be stacked on previous series. Mismatched length.",
                scalar(@{$self->{'data'}})
            )
            unless (scalar(@sorted) == scalar(@$prev));

        for (my $i = 0; $i < @sorted; $i++) {
            # check the time value matches
            croak
                sprintf(
                    "Series %d can not be stacked on previous series. Mismatched timestamp at sample %d (time %s).",
                    scalar(@{$self->{'data'}}),
                    $i,
                    HTTP::Date::time2iso($sorted[$i][0])
                )
            unless ($sorted[$i][0] == $prev->[$i][0]);

            $sorted[$i][1] += $prev->[$i][1];
        }
    }

    my %store = ('pairs' => \@sorted,);

    $store{'title'} = $conf->{'title'} if defined $conf->{'title'};
    push (@{$self->{'data'}}, \%store);

    return 1;
}

# Helper function for doing date/time calculations
# Current implementations of DateTime can be slow :-(
sub dateadd {
    my($epoch, $value, $unit) = @_;

    my $dt = DateTime->from_epoch(epoch => $epoch);
    $dt->add( $unit => $value );

    return $dt->epoch();
}

# override calculations to set a few calculated values, mainly for scaling
sub calculations {
    my $self = shift;

    # run through the data and calculate maximum and minimum values
    my($max_key_size, $max_time, $min_time, $max_value, $min_value,
       $max_x_label_length, $x_label);

    foreach my $dataset (@{$self->{data}}) {
        $max_key_size = length($dataset->{title})
            if     !defined $max_key_size
                || $max_key_size < length($dataset->{title});

        foreach my $pair (@{$dataset->{pairs}}) {
            $max_time = $pair->[0]
                if !defined $max_time || $max_time < $pair->[0];
            $min_time = $pair->[0]
                if !defined $min_time || $min_time > $pair->[0];
            $max_value = $pair->[1]
                if (   $pair->[1] ne ''
                    && (!defined $max_value || $max_value < $pair->[1]));
            $min_value = $pair->[1]
                if (   $pair->[1] ne ''
                    && (!defined $min_value || $min_value > $pair->[1]));

            $x_label = strftime($self->{config}->{x_label_format},localtime($pair->[0]));
            $max_x_label_length = length($x_label)
                if (   !defined $max_x_label_length
                    || $max_x_label_length < length($x_label));
        }
    }

    $self->{calc}->{max_key_size} = $max_key_size;
    $self->{calc}->{max_time}     = $max_time;
    $self->{calc}->{min_time}     = $min_time;
    $self->{calc}->{max_value}    = $max_value;
    $self->{calc}->{min_value}    = $min_value;
    $self->{calc}->{max_x_label_length} = $max_x_label_length;

    # Calc the x axis scale values
    $self->{calc}->{min_timescale_value}
        = $self->_is_valid_config('min_timescale_value')
        ? str2time($self->{config}->{min_timescale_value})
        : $min_time;
    $self->{calc}->{max_timescale_value}
        = $self->_is_valid_config('max_timescale_value')
        ? str2time($self->{config}->{max_timescale_value})
        : $max_time;
    $self->{calc}->{timescale_range}
        = $self->{calc}->{max_timescale_value}
            - $self->{calc}->{min_timescale_value};

    # Calc the y axis scale values
    $self->{calc}->{min_scale_value}
        = $self->_is_valid_config('min_scale_value')
        ? $self->{config}->{min_scale_value} : $min_value;
    $self->{calc}->{max_scale_value}
        = $self->_is_valid_config('max_scale_value')
        ? $self->{config}->{max_scale_value} : $max_value;
    $self->{calc}->{scale_range}
        = $self->{calc}->{max_scale_value} - $self->{calc}->{min_scale_value};

    my($range,$division,$precision);

    if ($self->_is_valid_config('scale_divisions')) {
        $division = $self->{config}->{scale_divisions};

        if ($division >= 1) {
            $precision = 0;
        }
        else {
            $precision = length($division) - 2;
        }
    }
    else {
        # Find divisions, format and range
        ($range, $division, $precision)
            = $self->_range_calc($self->{calc}->{scale_range});

        # If a max value hasn't been set we can set a revised range and max value
        if (!$self->_is_valid_config('max_scale_value')) {
            $self->{calc}->{max_scale_value}
                = $self->{calc}->{min_scale_value} + $range;
            $self->{calc}->{scale_range}
                = $self->{calc}->{max_scale_value}
                    - $self->{calc}->{min_scale_value};
        }
    }

    $self->{calc}->{scale_division} = $division;
    #XXX $self->{calc}->{scale_division} = 500;

    $self->{calc}->{y_label_format}
        = $self->_is_valid_config('y_label_format')
        ? $self->{config}->{y_label_format} : "%.${precision}f";
    $self->{calc}->{data_value_format}
        = $self->_is_valid_config('data_value_format')
        ? $self->{config}->{data_value_format} : "%.${precision}f";
}

sub prepare {
    my $self = shift;

    my $config = $self->{config};
    my $calc   = $self->{calc};
    my @data   = @{ $self->{data} };

    my $width  = $config->{width};
    my $height = $config->{height};

    my $x = 0;
    my $y = 0;

    my $char_width       = 8;
    my $half_char_height = 2.5;
    my $stagger = 0;
    my $key_box_size = 12;
    my $key_padding  = 5;
    my $x_label_allowance = 0;

    if ($config->{show_x_labels}) {
        $height = $height - 20;
    }

    if ($config->{rotate_x_labels}) {
        $x_label_allowance = $calc->{max_x_label_length} * $char_width - 20;
        $height = $height - $x_label_allowance;
    }

    if ($config->{show_x_labels} && $config->{stagger_x_labels}) {
        $stagger = 17;
        $height = $height - $stagger;
    }

    if ($config->{show_x_title}) {
        $height = $height - 25 - $stagger;
    }

    if ($config->{show_y_labels}) {
        $height = $height - 10;
        $y = $y + 10;
    }

    if ($config->{show_graph_title}) {
        $height = $height - 25;
        $y = $y + 25;
    }

    if ($config->{show_graph_subtitle}) {
        $height = $height - 10;
        $y = $y + 10;
    }

    if ($config->{key} && $config->{key_position} eq 'right') {
        $width = $width - $calc->{max_key_size} * ($char_width - 1)
            - 3 * $key_box_size;
    }
    elsif ($config->{key} && $config->{key_position} eq 'bottom') {
        my $scale = $#data < 4 ? (1 + $#data) : 4;
        $height = $height - $scale * ($key_box_size + $key_padding);
    }

    my $base_line = $height + $y;
    my $max_value_length = length($calc->{max_scale_value});
    my $max_value_length_px = $max_value_length * $char_width;
    my $space_b4_y_axis
        = (
            #XXXlength(date.format($calc->{min_timescale_value}, $config->{x_label_format}))
            100
            / 2) * $char_width;

    if ($config->{show_x_labels}) {
        my $scale = ($config->{key} && $config->{key_position} eq 'right')
            ? 1 : 2;

        $width = $width - $scale * $space_b4_y_axis;
        $x = $x + $space_b4_y_axis;
    }
    elsif ($config->{show_data_values}) {
        $width = $width - 2 * $max_value_length_px;
        $x = $x + $max_value_length_px;
    }

    if ($config->{show_y_labels} && $space_b4_y_axis < $max_value_length_px) {
        my $scale = $max_value_length < 2 ? 2 : 1;

        $width = $width - $scale * $max_value_length_px;
        $x = $x + $scale * $max_value_length_px;
    }
    elsif ($config->{show_y_labels} && !$config->{show_x_labels}) {
        $width = $width - $max_value_length_px;
        $x = $x + $max_value_length_px;
    }

    if ($config->{show_y_title}) {
        $width = $width - 25;
        $x = $x + 25;
    }

    my $max_time_span = 0;
    my $max_time_span_units;

    if ($config->{max_time_span} =~ m/(\d+) ?(\w+)?/) {
        $max_time_span = $0;
        $max_time_span_units = $1 ? $1 : 'days';
    }
}

1;
__DATA__
<?xml version="1.0"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.0//EN"
  "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">

[% USE date %]

<?xml-stylesheet href="[% config.style_sheet %]" type="text/css"?>

<svg width="[% config.width %]"
  height="[% config.height %]"
  viewBox="0 0 [% config.width %] [% config.height %]"
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink">

<rect x="0" y="0" width="[% config.width %]"
  height="[% config.height %]" class="svgBackground"/>

[%
    w = config.width;
    height = config.height;
    x = 0;
    y = 0;

    char_width       = 8;
    half_char_height = 2.5;
    stagger = 0;
    key_box_size = 12;
    key_padding  = 5;
%]

[% IF config.show_x_labels %]
    [% height = height - 20 %]
[% END %]

[% x_label_allowance = 0 %]
[% IF config.rotate_x_labels %]
    [% x_label_allowance = (calc.max_x_label_length * char_width) - 20 %]
    [% height = height - x_label_allowance %]
[% END %]

[% IF config.show_x_labels && config.stagger_x_labels %]
    [% stagger = 17 %]
    [% height = height - stagger %]
[% END %]

[% IF config.show_x_title %]
    [% height = height - 25 - stagger %]
[% END %]

[% IF config.show_y_labels %]
    [% height = height - 10 %]
    [% y = y + 10 %]
[% END %]

[% IF config.show_graph_title %]
    [% height = height - 25 %]
    [% y = y + 25 %]
[% END %]

[% IF config.show_graph_subtitle %]
    [% height = height - 10 %]
    [% y = y + 10 %]
[% END %]

[% IF config.key && config.key_position == 'right' %]
    [% w = w - (calc.max_key_size * (char_width - 1)) - (key_box_size * 3 ) %]
[% ELSIF config.key && config.key_position == 'bottom' %]
    [% IF data.size < 4 %]
        [% height = height - ((data.size + 1) * (key_box_size + key_padding)) %]
    [% ELSE %]
        [% height = height - (4 * (key_box_size + key_padding)) %]
    [% END %]
[% END %]

[% base_line = height + y %]

[% max_value_length = calc.max_scale_value.length %]

[% max_value_length_px = max_value_length * char_width %]

[% space_b4_y_axis = (date.format(calc.min_timescale_value,config.x_label_format).length / 2) * char_width %]

[% IF config.show_x_labels %]
    [% IF config.key && config.key_position == 'right' %]
        [% w = w - space_b4_y_axis %]
    [% ELSE %]
        [% w = w - (space_b4_y_axis * 2) %]
    [% END %]
    [% x = x + space_b4_y_axis %]
[% ELSIF config.show_data_values %]
    [% w = w - (max_value_length_px * 2) %]
    [% x = x + max_value_length_px %]
[% END %]

[% IF config.show_y_labels && space_b4_y_axis < max_value_length_px %]
    [% IF max_value_length < 2 %]
        [% w = w - (max_value_length * (char_width * 2)) %]
        [% x = x + (max_value_length * (char_width * 2)) %]
    [% ELSE %]
        [% w = w - max_value_length_px %]
        [% x = x + max_value_length_px %]
    [% END %]
[% ELSIF config.show_y_labels && !config.show_x_labels %]
    [% w = w - max_value_length_px %]
    [% x = x + max_value_length_px %]
[% END %]

[% IF config.show_y_title %]
    [% w = w - 25 %]
    [% x = x + 25 %]
[% END %]

[% max_time_span = 0 %]
[% IF (matches = config.max_time_span.match('(\d+) ?(\w+)?')) %]
    [% max_time_span = matches.0 %]
    [% IF (matches.1) %]
        [% max_time_span_units = matches.1 %]
    [% ELSE %]
        [% max_time_span_units = 'days' %]
    [% END %]
[% END %]

<rect x="[% x %]"
  y="[% y %]"
  width="[% w %]"
  height="[% height %]"
  class="graphBackground"/>
<clipPath id="clipGraphArea">
    <rect x="[% x %]" y="[% y %]" width="[% w %]" height="[% height %]"/>
</clipPath>

<path d="M[% x %] [% y %] v[% height %]" class="axis" id="xAxis"/>
<path d="M[% x %] [% base_line %] h[% w %]" class="axis" id="yAxis"/>

[% dx = calc.timescale_range %]
[% dw = w / dx %]

[% IF config.show_x_labels %]
<text x="[% x %]" y="[% base_line + 15 %]" [% IF config.rotate_x_labels %] transform="rotate(90 [% x  - half_char_height %] [% base_line + 15 %]) translate(-10,0)" style="text-anchor: start" [% END %] class="xAxisLabels">[% date.format(calc.min_timescale_value,config.x_label_format) %]</text>
    [% last_label = date.format(calc.min_timescale_value,config.x_label_format) %]
    [% IF config.timescale_divisions %]
        [% IF (matches = config.timescale_divisions.match('(\d+) ?(\w+)?')) %]
            [% timescale_division = matches.0 %]
            [% IF (matches.1) %]
                [% timescale_division_units = matches.1 %]
            [% ELSE %]
                [% timescale_division_units = 'days' %]
            [% END %]
            [% x_value = config.dateadd(calc.min_timescale_value,timescale_division,timescale_division_units) %]
            [% count = 0 %]
            [% WHILE ((x_value > calc.min_timescale_value) && ((x_value < calc.max_timescale_value))) %]
                [% xpos = (dw * (x_value - calc.min_timescale_value)) + x %]
                [% IF (config.stagger_x_labels && ((count % 2) == 0)) %]
                    <path d="M[% xpos %] [% base_line %] v[% stagger %]" class="staggerGuideLine" />
                    <text x="[% xpos %]" y="[% base_line + 15 + stagger %]" [% IF config.rotate_x_labels %] transform="rotate(90 [% xpos  - half_char_height %] [% base_line + 15 + stagger %]) translate(-10,0)" style="text-anchor: start" [% END %] class="xAxisLabels">[% date.format(x_value,config.x_label_format) %]</text>
                [% ELSE %]
                    <text x="[% xpos %]" y="[% base_line + 15 %]" [% IF config.rotate_x_labels %] transform="rotate(90 [% xpos  - half_char_height %] [% base_line + 15 %]) translate(-10,0)" style="text-anchor: start" [% END %] class="xAxisLabels">[% date.format(x_value,config.x_label_format) %]</text>
                [% END %]
                [% last_label = date.format(x_value,config.x_label_format) %]
                [% x_value = config.dateadd(x_value,timescale_division,timescale_division_units) %]
                [% count = count + 1 %]
                [% LAST IF (count >= 999) %]
            [% END %]
        [% END %]
    [% END %]
    [% IF date.format(calc.max_timescale_value,config.x_label_format) != last_label %]
<text x="[% x + w %]" y="[% base_line + 15 %]" [% IF config.rotate_x_labels %] transform="rotate(90 [% x + w - half_char_height %] [% base_line + 15 %]) translate(-10,0)" style="text-anchor: start" [% END %] class="xAxisLabels">[% date.format(calc.max_timescale_value,config.x_label_format) %]</text>
    [% END %]
[% END %]

[% top_pad = height / 40 %]

[% dy = calc.scale_range %]
[% dh = (height - top_pad) / dy %]

[% count = 0 %]
[% y_value = calc.min_scale_value %]
[% IF config.show_y_labels %]
    [% WHILE ((y_value == calc.min_scale_value) || (y_value == calc.max_scale_value) || ((y_value > calc.min_scale_value) && (y_value < calc.max_scale_value))) %]
        [%- next_label = y_value FILTER format(calc.y_label_format) -%]
        [%- IF count == 0 -%]
            [%# no stroke for first line %]
<text x="[% x - 5 %]" y="[% base_line - (dh * (y_value - calc.min_scale_value)) %]" class="yAxisLabels">[% next_label %]</text>
        [%- ELSE -%]
            [% IF next_label != last_label %]
<text x="[% x - 5 %]" y="[% base_line - (dh * (y_value - calc.min_scale_value)) %]" class="yAxisLabels">[% next_label %]</text>
<path d="M[% x %] [% base_line - (dh * (y_value - calc.min_scale_value)) %] h[% w %]" class="guideLines"/>
            [% END %]
        [%- END -%]
        [%- y_value = y_value + calc.scale_division -%]
        [%- last_label = next_label -%]
        [%- count = count + 1 -%]
        [%- LAST IF (count >= 999) -%]
    [% END %]
[% END %]

    [% IF config.show_x_title %]
        [% IF !config.show_x_labels %]
            [% y_xtitle = 15 %]
        [% ELSE %]
            [% y_xtitle = 35 %]
        [% END %]
<text x="[% (w / 2) + x %]" y="[% height + y + y_xtitle + stagger + x_label_allowance %]" class="xAxisTitle">[% config.x_title %]</text>
    [% END %]

    [% IF config.show_y_title %]
<text x="10" y="[% (height / 2) + y %]" transform="rotate(270,10,[% (height / 2) + y %])" class="yAxisTitle">[% config.y_title %]</text>
    [% END %]

[% line = data.size %]
<g id="groupData" class="data">
[% FOREACH dataset = data.reverse %]
<g id="groupDataSeries[% line %]"
  class="dataSeries[% line %]"
  clip-path="url(#clipGraphArea)">
    [% IF config.area_fill %]
        [% xcount = 0 %]
        [% FOREACH pair = dataset.pairs %]
            [%- IF ((pair.0 >= calc.min_timescale_value) && (pair.0 <= calc.max_timescale_value)) -%]
                [%- IF xcount == 0 -%][% lasttime = pair.0 %]<path d="M[% (dw * (pair.0 - calc.min_timescale_value)) + x %] [% base_line %][%- END -%]
                [%- IF ((max_time_span) && (pair.0 > config.dateadd(lasttime,max_time_span,max_time_span_units))) -%]
V [% base_line %] H [% (dw * (pair.0 - calc.min_timescale_value)) + x %] V [% base_line - (dh * (pair.1 - calc.min_scale_value)) %]
                [%- ELSE -%]
L [% (dw * (pair.0 - calc.min_timescale_value)) + x %] [% base_line - (dh * (pair.1 - calc.min_scale_value)) %]
                [%- END -%]
                [%- lasttime = pair.0 -%][%- xcount = xcount + 1 -%]
            [%- END -%]
        [% END %]
        [% IF xcount > 0 %] V [% base_line %] Z" class="fill[% line %]"/> [% END %]
    [% END %]

    [% xcount = 0 %]
    [% FOREACH pair = dataset.pairs %]
        [% IF ((pair.0 >= calc.min_timescale_value) && (pair.0 <= calc.max_timescale_value)) %]
            [%- IF xcount == 0 -%][%- lasttime = pair.0 -%]<path d="M
[% (dw * (pair.0 - calc.min_timescale_value)) + x %] [% base_line - (dh * (pair.1 - calc.min_scale_value)) %]
            [%- ELSE -%]
                [%- IF ((max_time_span) && (pair.0 > config.dateadd(lasttime,max_time_span,max_time_span_units))) -%]
M [% (dw * (pair.0 - calc.min_timescale_value)) + x %] [% base_line - (dh * (pair.1 - calc.min_scale_value)) %]
                [%- ELSE -%]
L [% (dw * (pair.0 - calc.min_timescale_value)) + x %] [% base_line - (dh * (pair.1 - calc.min_scale_value)) %]
                [%- END -%]
            [%- END -%]
            [%- lasttime = pair.0 -%][%- xcount = xcount + 1 -%]
        [%- END -%]
    [% END %]
    [% IF xcount > 0 %] " class="line[% line %]"/> [% END %]
</g>
<g id="groupDataLabels[% line %]" class="dataLabels[% line %]">
    [% IF config.show_data_points || config.show_data_values %]
        [% FOREACH pair = dataset.pairs %]
            [% IF ((pair.0 >= calc.min_timescale_value) && (pair.0 <= calc.max_timescale_value)) %]
<g class="dataLabel[% line %]" [% IF config.rollover_values %] opacity="0" [% END %]>
                [% IF config.show_data_points %]
<circle cx="[% (dw * (pair.0 - calc.min_timescale_value)) + x %]" cy="[% base_line - (dh * (pair.1 - calc.min_scale_value)) %]" r="2.5" class="fill[% line %]"
                    [% IF config.rollover_values %]
  onmouseover="evt.target.parentNode.setAttribute('opacity',1);"
  onmouseout="evt.target.parentNode.setAttribute('opacity',0);"
                    [% END %]
                    [% IF pair.3.defined %]
  onclick="[% pair.3 %]"
                    [% END %]
></circle>
                [% END %]
                [% IF config.show_data_values %]
                    [% IF (pair.2.defined) && (pair.2 != '') %][% point_label = pair.2 %][% ELSE %][% point_label = pair.1 FILTER format(calc.data_value_format) %][% END %]
<text x="[% (dw * (pair.0 - calc.min_timescale_value)) + x %]" y="[% base_line - (dh * (pair.1 - calc.min_scale_value)) - 6 %]" class="dataPointLabel[% line %]"
                    [% IF config.rollover_values %]
  onmouseover="evt.target.parentNode.setAttribute('opacity',1);"
  onmouseout="evt.target.parentNode.setAttribute('opacity',0);"
                    [% END %]
>[% point_label %]</text>
                [% END %]
</g>
            [% END %]
        [% END %]
    [% END %]
    </g>
    [% line = line - 1 %]
[% END %]
</g>

[% key_count = 1 %]
[% IF config.key && config.key_position == 'right' %]
    [% FOREACH dataset = data %]
<rect x="[% x + w + 20 %]" y="[% y + (key_box_size * key_count) + (key_count * key_padding) %]" width="[% key_box_size %]" height="[% key_box_size %]" class="key[% key_count %]"/>
<text x="[% x + w + 20 + key_box_size + key_padding %]" y="[% y + (key_box_size * key_count) + (key_count * key_padding) + key_box_size %]" class="keyText">[% dataset.title %]</text>
        [% key_count = key_count + 1 %]
    [% END %]
[% ELSIF config.key && config.key_position == 'bottom' %]
    [% y_key = base_line %]
    [% IF config.show_x_title %][% y_key = base_line + 25 %][% END %]
    [% IF config.rotate_x_labels && config.show_x_labels %]
        [% y_key = y_key + x_label_allowance %]
    [% ELSIF config.show_x_labels && stagger < 1 %]
        [% y_key = y_key + 20 %]
    [% END %]

    [% y_key_start = y_key %]
    [% x_key = x %]
    [% FOREACH dataset = data %]
        [% IF key_count == 4 || key_count == 7 || key_count == 10 %]
            [% x_key = x_key + 200 %]
            [% y_key = y_key - (key_box_size * 4) - 2 %]
        [% END %]
<rect x="[% x_key %]"
  y="[% y_key + (key_box_size * key_count) + (key_count * key_padding) + stagger %]" width="[% key_box_size %]" height="[% key_box_size %]" class="key[% key_count %]"/>
<text x="[% x_key + key_box_size + key_padding %]"
  y="[% y_key + (key_box_size * key_count) + (key_count * key_padding) + key_box_size + stagger %]" class="keyText">[% dataset.title %]</text>
        [% key_count = key_count + 1 %]
    [% END %]

[% END %]

[% IF config.show_graph_title %]
<text x="[% config.width / 2 %]" y="15" class="mainTitle">[% config.graph_title %]</text>
[% END %]

[% IF config.show_graph_subtitle %]
    [% IF config.show_graph_title %]
        [% y_subtitle = 30 %]
    [% ELSE %]
        [% y_subtitle = 15 %]
    [% END %]
<text x="[% config.width / 2 %]" y="[% y_subtitle %]" class="subTitle">[% config.graph_subtitle %]</text>
[% END %]
</svg>
