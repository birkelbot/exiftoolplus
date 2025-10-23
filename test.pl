#!/usr/bin/perl
use strict;
use warnings;

use lib '.';

use DateTime;
use Image::ExifToolPlus;

my $exiftool = Image::ExifToolPlus->new;


my $datetime = DateTime->new(
    year       => 2025,
    month      => 6,
    day        => 14,
    hour       => 7,
    minute     => 39,
    second     => 22,
    nanosecond => 500000000,
    time_zone  => '-0500',
);
# $exiftool->SetDateTime('C:/Users/mbirk/Desktop/Marathon Photos/Boston 2025/861650_1009_0036.jpg', $photo_datetime, Overwrite => 1);
# $exiftool->SetDateTime('C:/Users/mbirk/Downloads/20250421_boston-globe.jpg', $photo_datetime, Overwrite => 1);
# $exiftool->SetDateTime('C:/Users/mbirk/exiftoolplus/_test/Test_Video_DJI.mp4', $datetime, Overwrite => 1);
# $exiftool->SetDateTime('C:/Users/mbirk/Downloads/TEST/*.{mp4,jpg}', $datetime, Overwrite => 1, VerboseLogging => 1);
$exiftool->SetDateTime(qq('C:/Users/mbirk/Desktop/Steamboat/Z82_9213.jpg'), $datetime, Overwrite => 1, VerboseLogging => 1);

# $exiftool->PrintTagsToFile('C:/Users/mbirk/Downloads/TEST/*', DateTime => 1);
$exiftool->PrintTagsToFile(qq('C:/Users/mbirk/Desktop/Steamboat/Z82_9213.jpg'), DateTime => 1);
