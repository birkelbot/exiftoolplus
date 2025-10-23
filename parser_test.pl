#!/usr/bin/perl
use strict;
use warnings;

use DateTime::Format::Builder;

print "Attempting to create parser...\n";

# --- MINIMAL TEST: Parse YYYY-MM-DD (from documentation example) ---
my $parser = DateTime::Format::Builder->parser(
    params => [qw( year month day )], # Date parameters
    # Regex matches YYYY-MM-DD
    regex  => qr/^(\d{4})-(\d{2})-(\d{2})$/,
);

# Check parser creation immediately
die "Failed to create DateTime parser in test script."
    unless defined $parser && ref($parser) && $parser->can('parse');

print "Parser created successfully!\n";

# --- Test Cases ---
my @test_inputs = (
    "2024-05-31", # Valid YYYY-MM-DD
    "1999-12-01", # Valid YYYY-MM-DD
    "2024/05/31", # Invalid - wrong separator
    "24-05-31",   # Invalid - YY instead of YYYY
    "2024-5-31",  # Invalid - M instead of MM
    "",           # Invalid - empty string
);

foreach my $input (@test_inputs) {
    my $result = $parser->parse($input);
    print "Input: '$input' => Result: " . (defined $result ? "Parsed (y=$result->{year} m=$result->{month} d=$result->{day})" : "undef") . "\n";
}

print "Test finished.\n";
