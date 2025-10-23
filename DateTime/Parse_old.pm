package DateTime::Parse;

use strict;
use warnings;

use DateTime::Format::Builder;

use Exporter qw(import);
our @EXPORT_OK = qw( parse_datetime );

sub _make_regex {
  my $date_re = '(\d{4}) : (\d{2}) : (\d{2})';
  my $time_re = '(\d{2}) : (\d{2}) : (\d{2} (?: \. \d{1,9})?)';
  my $tz_re = '(Z | [\+\-] \d{2} : \d{2})';
  return qr/^ $date_re \s $time_re $tz_re? $/xms;
}


sub _postprocess {
  my %args = @_;
  my ($input, $parsed) = @args{qw( input parsed )};

  # Treat no explicitly listed time zone as UTC.
  if (!$parsed->{time_zone} or $parsed->{time_zone} eq 'Z') {
    $parsed->{time_zone} = 'UTC';
  }

  # Remove the colon from time zone offsets because that's what
  # DateTime::TimeZone expects.
  $parsed->{time_zone} =~ tr/://d;

  # Extract out the fractional seconds (nanoseconds), if present.
  my ($second, $fractional_second) = split(/\./, $parsed->{second});
  $parsed->{second} = $second;
  if ($fractional_second) {
    # THIS HAS A BUG! The number of digits after the decimal point can vary,
    # which means we need to multiply it by a variable power of 10.
    $parsed->{nanosecond} = int($fractional_second * 1e9)
  }
  return 1;
}

my $parser =
  DateTime::Format::Builder->parser(
    params => [ qw( year month day hour minute second time_zone ) ],
    regex  => _make_regex(),
    postprocess => \&_postprocess,
  );
  
# Check to ensure the parser object was created successfully and is valid.
die "Failed to create DateTime parser object. Check regex or postprocess function."
    unless defined $parser && ref($parser) && $parser->can('parse');

sub parse_datetime {
  my $datetime_string = shift(@_);

  return $parser->parse_datetime($datetime_string);
}

1;
