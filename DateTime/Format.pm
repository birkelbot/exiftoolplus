package DateTime::Format;

use strict;
use warnings;

use DateTime;

use Exporter qw(import);
our @EXPORT_OK = qw( extract_formatted_timezone format_datetime );

# ------------------------------------------------------------------------------
# Public Subroutines
# ------------------------------------------------------------------------------

# Extracts the time zone offset from a DateTime object and formats it
# with a colon (e.g., +05:00), as commonly used in EXIF data.
#
# Arguments:
#   $datetime - A DateTime object.
#
# Returns:
#   The formatted time zone string (e.g., "+05:00", "-08:00") on success.
#   undef if the input is not a valid DateTime object or if the offset cannot be
#     formatted correctly.
sub extract_formatted_timezone {
    my ($datetime) = @_;

    # Check if the input is a valid DateTime object.
    unless ( eval { $datetime->isa('DateTime') } ) {
        warn "Input is not a DateTime object" if $^W; # Warn if warnings are on
        return;  # Return undef.
    }

    # Get the time zone offset in +HHMM/-HHMM format.
    my $time_zone_offset = $datetime->strftime("%z");

    if ( $time_zone_offset =~ /^([+\-])(\d{2})(\d{2})$/ ) {
        # $1 = sign, $2 = hours, $3 = minutes
        return "$1$2:$3";
    }
    else {
        # Handle unexpected formats (e.g., potentially 'Z' or others,
        # though %z usually gives numeric offsets).
        warn "Unexpected time zone offset format: $time_zone_offset" if $^W;
        return;  # Return undef.
    }
}

# Formats a DateTime object into a specific string format, with options
# for customization (UTC conversion, sub-second precision, time zone).
# Format: YYYY-MM-DD HH:MM:SS[.fff][+/-HH:MM]
#
# Arguments:
#   $datetime - The DateTime object to format.
#   %options  - Hash of options:
#               ConvertToUTC => Boolean, convert to UTC before formatting.
#               OmitSubSec => Boolean, omit milliseconds.
#               ForceIncludeSubSec => Boolean, include milliseconds even if 0.
#               OmitTimeZone => Boolean, omit the time zone offset.
#
# Returns:
#   The formatted datetime string on success.
#   undef if the input is not a valid DateTime object.
sub format_datetime {
    my ($datetime_orig, %options) = @_;

    # Check if the input is a valid DateTime object.
    unless ( eval { $datetime_orig->isa('DateTime') } ) {
        warn "Input is not a DateTime object" if $^W;
        return;  # Return undef.
    }

    # Clone the input datetime object so modifications don't affect the caller.
    my $datetime = $datetime_orig->clone();

    # Convert to UTC if requested.
    if ( $options{ConvertToUTC} ) {
        # NOTE: set_time_zone modifies the object in place.
        $datetime->set_time_zone('UTC');
    }

    # Format the base date and time (YYYY-MM-DD HH:MM:SS).
    my $output = $datetime->strftime("%F %T");  # %F = %Y-%m-%d, %T = %H:%M:%S

    # Determine if sub-seconds (milliseconds) should be included.
    my $include_subsecs = $options{ForceIncludeSubSec}
      || ( !$options{OmitSubSec} && $datetime->nanosecond );

    # Append milliseconds if needed. %3N gives milliseconds.
    if ($include_subsecs) {
        $output .= '.' . $datetime->strftime("%3N");
    }

    # Append time zone offset unless omitted or if it's UTC (+00:00).
    unless ( $options{OmitTimeZone} ) {
        my $time_zone_str = extract_formatted_timezone($datetime);
        # Only add if the extraction was successful and it's not UTC.
        if ( defined $time_zone_str && $time_zone_str ne '+00:00' ) {
            $output .= $time_zone_str;
        }
    }

    return $output;
}

1;
