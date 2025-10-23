package DateTime::Parse;

use strict;
use warnings;

use DateTime::Format::Builder;

use Exporter qw(import);
our @EXPORT_OK = qw( parse_datetime );

# ------------------------------------------------------------------------------
# --- Private Subroutines
# ------------------------------------------------------------------------------

# Helper subroutine to handle fractional seconds parsing and nanosecond calculation.
#
# Arguments:
#   $parsed - Hashref of the parsed values (modified in place).
#
# Returns:
#   None. Modifies $parsed hashref directly.
sub _handle_fractional_seconds {
    my ($parsed) = @_; # Pass the hashref directly
    # Handle potential fractional seconds (nanoseconds).
    # This check is necessary as fractional seconds are optional.
    if ( $parsed->{second} =~ /\./ ) {
        # Split seconds into integer and fractional parts (limit to 2 parts).
        my ( $second, $fractional_second ) =
          split( /\./, $parsed->{second}, 2 );
        $parsed->{second} = $second;

        # Pad fractional part with trailing zeros to exactly 9 digits.
        $fractional_second = substr( $fractional_second . '0' x 9, 0, 9 );
        $parsed->{nanosecond} = int($fractional_second);
    }
    else {
        # Ensure nanosecond field exists even if there's no fractional part.
        $parsed->{nanosecond} = 0;
    }
}

# Postprocess callback for the parser.
# Sets the default time zone to 'UTC' and handles fractional seconds.
sub _postprocess {
    my ($args) = @_;
    my ($input, $parsed) = @{$args}{qw( input parsed )};

    # Always set default time zone to UTC since the regex doesn't capture one.
    $parsed->{time_zone} = 'UTC';

    _handle_fractional_seconds($parsed);
    # Return a true value to signal success to DateTime::Format::Builder.
    return 1;
}
# ------------------------------------------------------------------------------
# Parser Setup
# ------------------------------------------------------------------------------
# Define two parsers: one requiring a time zone, one without.
# This avoids potential issues with optional capture groups in DateTime::Format::Builder.

# Parser 1: Expects YYYY : MM : DD HH : MM : SS[.n] TZ
# REMOVED - Sticking to one simple parser for now.

# Define a single parser for YYYY:MM:DD HH:MM:SS[.n] (no time zone)
my $parser = DateTime::Format::Builder->parser(
    # --- MINIMAL TEST: Parse a 2-digit number ---
    params => [qw( number )], # Single parameter
    # Regex matches exactly two digits
    regex  => qr/^(\d{2})$/,
);
# Check parser creation
die "Failed to create DateTime parser."
    unless defined $parser && ref($parser) && $parser->can('parse');

# ------------------------------------------------------------------------------
# Public Subroutines
# ------------------------------------------------------------------------------

# Parses a datetime string into a DateTime object using the
# predefined format.
#
# Arguments:
#   $datetime_string - The string to parse
#                      (e.g., "2025 : 05 : 03 18 : 16 : 00.123 +05:00").
#
# Returns:
#   A DateTime object on successful parsing.
#   undef if the string does not match the expected format or is invalid
#         (e.g., undef, empty string). Relies on the underlying
#         DateTime::Format::Builder parser's handling of invalid input.
sub parse_datetime {
    my ($datetime_string) = @_;

    # Add basic validation for undef or empty input string.
    return undef unless defined $datetime_string && length $datetime_string;

    # Use the single parser. It returns undef on failure.
    my $dt = $parser->parse($datetime_string);
    return $dt; # Return result (DateTime object or undef)
}

1;
