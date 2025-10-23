package DateTime::Parse;

use strict;
use warnings;

use DateTime::Format::Builder;

use Exporter qw(import);
our @EXPORT_OK = qw( parse_datetime );

# ------------------------------------------------------------------------------
# --- Private Subroutines
# ------------------------------------------------------------------------------

# Constructs the regular expression for the expected datetime format.
# Format: YYYY : MM : DD HH : MM : SS[.n{1,9}] [Z|+/-HH:MM]
#
# Arguments:
#   None.
#
# Returns:
#   A compiled regular expression object (qr//).
sub _make_regex {
    # Date part: YYYY : MM : DD
    my $date_re = '(\d{4}) \s : \s (\d{2}) \s : \s (\d{2})';

    # Time part: HH : MM : SS[.fffffffff] (fractional seconds optional)
    my $time_re =
      '(\d{2}) \s : \s (\d{2}) \s : \s (\d{2} (?: \. \d{1,9})?)';

    # Time zone part: Z (UTC) or +/-HH:MM offset (optional)
    my $tz_re = '(Z | [\+\-] \d{2} \s : \s \d{2})';

    # Combine parts into a single regex, anchored to start/end of string.
    # x - extended mode (ignore whitespace, allow comments)
    # m - treat string as multiple lines
    # s - treat string as single line ('.' matches newline)
    return qr/^ $date_re \s $time_re (?: \s $tz_re)? $/xms;
}

# Cleans up and adjusts the data parsed by the regex.
# This is called as a postprocess callback by DateTime::Format::Builder.
#
# Arguments:
#   %args - Hash passed by DateTime::Format::Builder, containing:
#           input  => The original input string.
#           parsed => Hashref of the captured values from the regex.
#                     (This hashref is modified in place).
#
# Returns:
#   1 to indicate successful post-processing.
sub _postprocess {
    my %args = @_;

    # Extract input string and parsed results hash from arguments.
    # qw() is a Perl shortcut for creating a list of quoted words.
    my ($input, $parsed) = @args{qw( input parsed )};

    # Default to UTC if no time zone is specified or if it's 'Z'.
    if ( !defined $parsed->{time_zone} or $parsed->{time_zone} eq 'Z' ) {
        $parsed->{time_zone} = 'UTC';
    }
    else {
        # Remove colons from HH:MM offset for DateTime::TimeZone
        # compatibility using the transliteration operator (tr///).
        $parsed->{time_zone} =~ tr/://d;
    }

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

    # Return a true value to signal success to DateTime::Format::Builder.
    return 1;
}

# ------------------------------------------------------------------------------
# Parser Setup
# ------------------------------------------------------------------------------

# Create the parser instance using DateTime::Format::Builder.
# This pre-compiles the parsing logic using the regex and post-processing
# subroutine defined above for efficiency.
my $parser = DateTime::Format::Builder->parser(
    # Map regex capture groups ($1, $2, etc.) to named parameters for DateTime.
    params => [qw( year month day hour minute second time_zone )],
    # The regex used to match and capture datetime components.
    regex  => _make_regex(),
    # The subroutine reference (\&) to call after a successful regex match
    # for cleanup/adjustment.
    postprocess => \&_postprocess,
);

# Check to ensure the parser object was created successfully and is valid.
die "Failed to create DateTime parser object. Check regex or postprocess function."
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

    # Use the pre-built parser object to parse the string.
    # The $parser->parse method handles non-matching/invalid input
    # by returning undef, so explicit checks here are redundant.
    return $parser->parse($datetime_string);
}

1;
