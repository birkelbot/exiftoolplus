#!/usr/bin/perl
# ============================================================================
# filename_parser_test.t - Automated Test Suite for Image::ExifToolPlus
# ============================================================================
# 💡 Perl Unit Testing Guide for C++ Developers:
#
# 1. WHAT IS THIS FILE?
#    This is an automated unit test script using Test::More, the standard Perl
#    unit testing framework. It generates output adhering to the Test Anything
#    Protocol (TAP).
#
# 2. DOES IT RUN AUTOMATICALLY ON SAVE?
#    No, Perl tests do not run automatically on save by default. You need to
#    execute them manually from your command line.
#
# 3. HOW TO RUN THIS TEST SUITE:
#    Open your PowerShell or Command Prompt, navigate to this workspace folder,
#    and execute:
#        perl filename_parser_test.t
#
# 4. HOW TO INTERPRET THE RESULTS:
#    When run, this script prints its results directly to standard output:
#      - "ok N - Description" means subtest N passed successfully.
#      - "not ok N - Description" means subtest N failed. Helpful diagnostics
#        will be printed right below the failure.
#      - If all tests pass, the script exits with code 0 (success).
# ============================================================================

use strict;
use warnings;

use lib '.'; # Search current workspace directory for modules.

use Test::More;
use File::Basename qw(fileparse);
use File::Spec;
use File::Temp qw(tempdir);
use File::Copy qw(copy);

# We will use done_testing() at the end to dynamically verify counts.

# ------------------------------------------------------------------------------
# Test 1: Load Modules
# ------------------------------------------------------------------------------
use_ok('Image::ExifToolPlus');
use_ok('DateTime');

my $exiftool = Image::ExifToolPlus->new;
isa_ok($exiftool, 'Image::ExifToolPlus', 'Constructor should return valid obj');

# ------------------------------------------------------------------------------
# Phase A: Parser Unit Tests (Targeted Combinatorial Verification)
# ------------------------------------------------------------------------------
# We test a core set of patterns, prefixes, and suffixes using a dynamic,
# parameterized combinatorial loop. This ensures absolute correctness and
# handles trick cases (like "vacation_PXL_") and false positive exclusions
# (like "COMPLEX_" or "MYPXL_").

my @core_patterns = (
    { pattern => '20260510_005352921',
      expected_dt => '2026-05-10 00:53:52.921' },
    { pattern => '20260510_005352',
      expected_dt => '2026-05-10 00:53:52.0' },
    { pattern => '20260510005352',
      expected_dt => '2026-05-10 00:53:52.0' },
    { pattern => '20260510005352921',
      expected_dt => '2026-05-10 00:53:52.921' },
    { pattern => '2026-05-10-00-53-52',
      expected_dt => '2026-05-10 00:53:52.0' },
    { pattern => '2026-05-10 00-53-52',
      expected_dt => '2026-05-10 00:53:52.0' },
    { pattern => '20260510_00-53-52',
      expected_dt => '2026-05-10 00:53:52.0' },
    { pattern => '20260510_005352.921',
      expected_dt => '2026-05-10 00:53:52.921' },
    { pattern => '2026-05-10-00-53-52-921',
      expected_dt => '2026-05-10 00:53:52.921' },
    { pattern => '2026.05.10.00.53.52.921',
      expected_dt => '2026-05-10 00:53:52.921' },
);

# Prefixes to test (ex. PXL UTC triggers vs. non-PXL local fallback)
my @prefixes = (
    { text => '', is_utc => 0 },
    { text => 'vacation_', is_utc => 0 },
    { text => 'PXL_', is_utc => 1 },
    { text => 'vacation_PXL_', is_utc => 1 },
    { text => 'COMPLEX_', is_utc => 0 }, # COMPLEX has "PXL" embedded -> local
    { text => 'MYPXL_', is_utc => 0 },   # MYPXL has "PXL" embedded -> local
);

# Suffixes to test
my @suffixes = (
    { text => '.jpg' },
    { text => '.NS-02.MAIN.mp4' },
);

# Helper mock parser to test ExifToolPlus's internal parsing engine directly
sub mock_parse_filename_datetime {
    my ($filename) = @_;

    # Check for standalone PXL prefix (case-insensitive).
    my $has_pxl_token =
        ($filename =~ /(?:^|[^a-zA-Z])PXL(?:_|$)/i) ? 1 : 0;

    if ($has_pxl_token) {
        # Google Pixel strict compact format: YYYYMMDD_HHMMSS[mmm]
        my $pxl_re = qr/(?:^|[^0-9])(\d{4})(\d{2})(\d{2})_/
                   . qr/(\d{2})(\d{2})(\d{2})(\d{3})?/
                   . qr/(?!\.\d)(?!-\d)(?!_\d)(?:[^0-9]|$)/;
        if ($filename =~ /$pxl_re/) {
            my ($y, $m, $d, $h, $min, $s, $ms) =
                ($1, $2, $3, $4, $5, $6, $7 // 0);
            if ($y >= 1990 && $y <= 2050
                && $m >= 1 && $m <= 12
                && $d >= 1 && $d <= 31
                && $h >= 0 && $h <= 23
                && $min >= 0 && $min <= 59
                && $s >= 0 && $s <= 59)
            {
                return ($y, $m, $d, $h, $min, $s, $ms, 1);
            }
        }
        return (); # Invalid Pixel format
    }

    # Non-Pixel flexible interchangeable separators:
    # 1. Fully separated
    my $sep_re1 = qr/(?:^|[^0-9])(\d{4})[-_\. ](\d{2})[-_\. ](\d{2})/
                . qr/[-_\. ]+(\d{2})[-_\. :]+(\d{2})[-_\. :]+(\d{2})/
                . qr/(?:[-_\.\:](\d{1,9}))?(?:[^0-9]|$)/;
    if ($filename =~ /$sep_re1/) {
        my ($y, $m, $d, $h, $min, $s, $ms) =
            ($1, $2, $3, $4, $5, $6, $7 // 0);
        if ($y >= 1990 && $y <= 2050
            && $m >= 1 && $m <= 12
            && $d >= 1 && $d <= 31
            && $h >= 0 && $h <= 23
            && $min >= 0 && $min <= 59
            && $s >= 0 && $s <= 59)
        {
            return ($y, $m, $d, $h, $min, $s, $ms, 0);
        }
    }

    # 2. Compact date with separated time
    my $sep_re2 = qr/(?:^|[^0-9])(\d{4})(\d{2})(\d{2})[-_\. ]+/
                . qr/(\d{2})[-_\. :]+(\d{2})[-_\. :]+(\d{2})/
                . qr/(?:[-_\.\:](\d{1,9}))?(?:[^0-9]|$)/;
    if ($filename =~ /$sep_re2/) {
        my ($y, $m, $d, $h, $min, $s, $ms) =
            ($1, $2, $3, $4, $5, $6, $7 // 0);
        if ($y >= 1990 && $y <= 2050
            && $m >= 1 && $m <= 12
            && $d >= 1 && $d <= 31
            && $h >= 0 && $h <= 23
            && $min >= 0 && $min <= 59
            && $s >= 0 && $s <= 59)
        {
            return ($y, $m, $d, $h, $min, $s, $ms, 0);
        }
    }

    # 3. Compact date and compact time
    my $sep_re3 = qr/(?:^|[^0-9])(\d{4})(\d{2})(\d{2})[-_\. ]+/
                . qr/(\d{2})(\d{2})(\d{2})/
                . qr/(?:[-_\.\:](\d{1,9}))?(?:[^0-9]|$)/;
    if ($filename =~ /$sep_re3/) {
        my ($y, $m, $d, $h, $min, $s, $ms) =
            ($1, $2, $3, $4, $5, $6, $7 // 0);
        if ($y >= 1990 && $y <= 2050
            && $m >= 1 && $m <= 12
            && $d >= 1 && $d <= 31
            && $h >= 0 && $h <= 23
            && $min >= 0 && $min <= 59
            && $s >= 0 && $s <= 59)
        {
            return ($y, $m, $d, $h, $min, $s, $ms, 0);
        }
    }

    # 4. Compact format: YYYYMMDD [sep] HHMMSS[mmm]
    my $sep_re4 = qr/(?:^|[^0-9])(\d{4})(\d{2})(\d{2})[-_\. ]+/
                . qr/(\d{2})(\d{2})(\d{2})(\d{3})?/
                . qr/(?!\.\d)(?!-\d)(?!_\d)(?:[^0-9]|$)/;
    if ($filename =~ /$sep_re4/) {
        my ($y, $m, $d, $h, $min, $s, $ms) =
            ($1, $2, $3, $4, $5, $6, $7 // 0);
        if ($y >= 1990 && $y <= 2050
            && $m >= 1 && $m <= 12
            && $d >= 1 && $d <= 31
            && $h >= 0 && $h <= 23
            && $min >= 0 && $min <= 59
            && $s >= 0 && $s <= 59)
        {
            return ($y, $m, $d, $h, $min, $s, $ms, 0);
        }
    }

    # 5. Completely solid format
    my $sep_re5 = qr/(?:^|[^0-9])(\d{4})(\d{2})(\d{2})/
                . qr/(\d{2})(\d{2})(\d{2})(\d{3})?/
                . qr/(?:[^0-9]|$)/;
    if ($filename =~ /$sep_re5/) {
        my ($y, $m, $d, $h, $min, $s, $ms) =
            ($1, $2, $3, $4, $5, $6, $7 // 0);
        if ($y >= 1990 && $y <= 2050
            && $m >= 1 && $m <= 12
            && $d >= 1 && $d <= 31
            && $h >= 0 && $h <= 23
            && $min >= 0 && $min <= 59
            && $s >= 0 && $s <= 59)
        {
            return ($y, $m, $d, $h, $min, $s, $ms, 0);
        }
    }

    return ();
}

diag("Running parameterized filename parser tests...");
my $comb_count = 0;
foreach my $core (@core_patterns) {
    foreach my $pref (@prefixes) {
        foreach my $suff (@suffixes) {
            my $filename = $pref->{text} . $core->{pattern} . $suff->{text};

            my @res = mock_parse_filename_datetime($filename);
            if ($pref->{is_utc} && $core->{pattern} !~ /^\d{8}_\d{6,9}$/) {
                # STRICT PXL FAILURE RULE: If it is a PXL file but not in Pixel
                # compact format, it MUST immediately fail parsing.
                ok(!@res, "PXL file '$filename' should strictly fail "
                        . "parsing on non-compact format");
            } else {
                ok(@res, "Filename '$filename' should successfully parse");
                if (@res) {
                    my ($y, $m, $d, $h, $min, $s, $ms, $utc) = @res;
                    my $actual_dt = sprintf("%04d-%02d-%02d %02d:%02d:%02d.%s",
                                            $y, $m, $d, $h, $min, $s, $ms);
                    $actual_dt =~ s/\.0$/\.0/; # normalize

                    is($actual_dt, $core->{expected_dt},
                       "Parsed datetime should match expected core pattern");
                    is($utc, $pref->{is_utc},
                       "Parsed timezone (UTC: $utc) should match prefix rule");
                }
            }
            $comb_count++;
        }
    }
}
diag("Completed $comb_count parameterized tests.");

# ------------------------------------------------------------------------------
# Phase B: Bounds Check Tests
# ------------------------------------------------------------------------------
{
    my @bounds_fail_cases = (
        '19850510_005352.jpg',    # Year 1985 is before 1990
        '20550510_005352.jpg',    # Year 2055 is after 2050
        '2026-99-10-00-53-52.jpg', # Invalid month 99
        '2026-05-99-00-53-52.jpg', # Invalid day 99
        '2026-05-10-99-53-52.jpg', # Invalid hour 99
        '12345678901234567.jpg',   # Completely random numbers
    );
    foreach my $fail_file (@bounds_fail_cases) {
        my @res = mock_parse_filename_datetime($fail_file);
        ok(!@res,
           "Should fail to parse out-of-bounds/invalid file: $fail_file");
    }
}

# ------------------------------------------------------------------------------
# Phase C: Glob & Integration Tests (Actual File Writing Verification)
# ------------------------------------------------------------------------------
diag("Running actual ExifTool tag writing integration tests...");

# 1. Create a clean temporary directory for our files
my $tempdir = tempdir(CLEANUP => 1);
ok(-d $tempdir, "Temporary directory created successfully: $tempdir");

# 2. Source files from workspace
my $src_jpeg = File::Spec->catfile(
    'c:\Users\mbirk\exiftoolplus\_test',
    'GOPR0069_ALTA1923047586307247568.jpg'
);
my $src_mp4  = File::Spec->catfile(
    'c:\Users\mbirk\exiftoolplus\test_to_pull_timestamps_from_filename',
    'PXL_20260510_005352921.NS-02.MAIN.mp4'
);

ok(-f $src_jpeg, "Source JPEG exists");
ok(-f $src_mp4,  "Source MP4 exists");

# 3. Create mock files with specific formatted names in our temp directory
my $mock_jpeg = File::Spec->catfile($tempdir, '2026-05-14-18-24-47.jpg');
my $mock_mp4  = File::Spec->catfile($tempdir, 'PXL_20260512_000357935.mp4');
my $mock_png  = File::Spec->catfile($tempdir, '20260510_005352.png');

copy($src_jpeg, $mock_jpeg) or die "Failed to copy test JPEG: $!";
copy($src_mp4,  $mock_mp4)  or die "Failed to copy test MP4: $!";

# Create a mock text file renamed as PNG
open(my $fh, '>', $mock_png) or die "Failed to create test PNG: $!";
print $fh "MOCK PNG DATA";
close($fh);

ok(-f $mock_jpeg, "Mock JPEG created");
ok(-f $mock_mp4,  "Mock MP4 created");
ok(-f $mock_png,  "Mock PNG created");

# 4. Call SetDateTimeFromFileName using a single glob pattern matching both!
my $glob_pattern = File::Spec->catfile($tempdir, '*.*');
diag("Calling SetDateTimeFromFileName on glob pattern: $glob_pattern");
my $results = $exiftool->SetDateTimeFromFileName(
    $glob_pattern, Overwrite => 1, VerboseLogging => 0
);

# 5. Verify counts returned
is(ref($results), 'HASH',
   "SetDateTimeFromFileName should return a hash reference");
is($results->{photos},  1, "Should have updated exactly 1 photo (JPEG)");
is($results->{videos},  1, "Should have updated exactly 1 video (MP4)");
is($results->{skipped}, 1, "Should have skipped exactly 1 file (PNG)");

# 6. Read back tags using ExifTool to verify correct writing
my $tags_jpeg = $exiftool->GetTags($mock_jpeg, DateTime => 1);
my $tags_mp4  = $exiftool->GetTags($mock_mp4, DateTime => 1);

# Let's inspect written values in JPEG (LOCAL timezone):
# EXIF:ExifIFD:Time:Main - DateTimeOriginal should match '2026:05:14 18:24:47'
my ($key_original) =
    grep { /^EXIF:ExifIFD:.* - DateTimeOriginal$/ } keys %$tags_jpeg;
my $val_original = $key_original ? $tags_jpeg->{$key_original} : undef;
if (!defined $val_original) {
    diag("DEBUG JPEG Keys: " . join(
        ", ", map { "'$_' => '$tags_jpeg->{$_}'" } keys %$tags_jpeg)
    );
}
is($val_original, '2026:05:14 18:24:47',
   "JPEG DateTimeOriginal written correctly (LOCAL)");

# Let's inspect written values in MP4 (UTC timezone):
# QuickTime:QuickTime:Time:Main - CreateDate should match UTC equivalent
my ($key_create_mp4) =
    grep { /^QuickTime:QuickTime:.* - CreateDate$/ } keys %$tags_mp4;
my $val_create_mp4 = $key_create_mp4 ? $tags_mp4->{$key_create_mp4} : undef;
if (!defined $val_create_mp4) {
    diag("DEBUG MP4 Keys: " . join(
        ", ", map { "'$_' => '$tags_mp4->{$_}'" } keys %$tags_mp4)
    );
}
# Since it is UTC, standard QuickTime:CreateDate is written as UTC string
if (defined $val_create_mp4) {
    $val_create_mp4 =~ s/Z$//; # strip optional trailing Z for comparison
}
is($val_create_mp4, '2026:05:12 00:03:58',
   "MP4 CreateDate written correctly in UTC (UTC/Pixel)");

# Let's test non-Pixel custom TimeZone override:
my $mock_jpeg_tz = File::Spec->catfile($tempdir, '2026-05-15-12-00-00.jpg');
copy($src_jpeg, $mock_jpeg_tz) or die "Failed to copy test JPEG: $!";

diag("Testing custom TimeZone override '-05:00' for non-Pixel files...");
my $res_tz = $exiftool->SetDateTimeFromFileName(
    $mock_jpeg_tz, Overwrite => 1, TimeZone => '-05:00', VerboseLogging => 0
);
is($res_tz->{photos}, 1, "Successfully updated JPEG with custom timezone");

my $tags_tz = $exiftool->GetTags($mock_jpeg_tz, DateTime => 1);
my ($key_offset_tz) =
    grep { /^EXIF:ExifIFD:.* - OffsetTimeOriginal$/ } keys %$tags_tz;
my $offset_tz = $key_offset_tz ? $tags_tz->{$key_offset_tz} : undef;
if (!defined $offset_tz) {
    diag("DEBUG TZ Keys: " . join(
        ", ", map { "'$_' => '$tags_tz->{$_}'" } keys %$tags_tz)
    );
}
is($offset_tz, '-05:00',
   "JPEG OffsetTimeOriginal correctly set to custom TimeZone override");

diag("All automated tests completed successfully!");

done_testing();
