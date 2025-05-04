#!/usr/bin/perl
use strict;
use warnings;

use lib '.';

use DateTime;
use Image::ExifToolPlus;

my $exiftool = Image::ExifToolPlus->new;


my $datetime = DateTime->new(
    year       => 2025,
    month      => 5,
    day        => 3,
    hour       => 11,
    minute     => 07,
    second     => 41,
    nanosecond => 0,
    time_zone  => '-0400',
);
# $exiftool->SetDateTime('C:/Users/mbirk/Desktop/Marathon Photos/Boston 2025/861650_1009_0036.jpg', $photo_datetime, Overwrite => 1);
# $exiftool->SetDateTime('C:/Users/mbirk/Downloads/20250421_boston-globe.jpg', $photo_datetime, Overwrite => 1);
# $exiftool->SetDateTime('C:/Users/mbirk/exiftoolplus/_test/Test_Video_DJI.mp4', $datetime, Overwrite => 1);
$exiftool->SetDateTime('C:/Users/mbirk/Downloads/TEST/*.{mp4,jpg}', $datetime, Overwrite => 1, VerboseLogging => 1);

# $exiftool->PrintTagsToFile('C:/Users/mbirk/Downloads/TEST/*', DateTime => 1);
