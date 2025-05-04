#!/usr/bin/perl
use strict;
use warnings;

use lib '.';

use DateTime;
use Image::ExifToolPlus;

my $exiftool = Image::ExifToolPlus->new;


my $video_datetime = DateTime->new(
    year       => 2025,
    month      => 5,
    day        => 3,
    hour       => 11,
    minute     => 07,
    second     => 41,
    nanosecond => 0,
    time_zone  => '-0400',
);
# $exiftool->SetVideoDateTime('F:/Pixel - Matt/Others/Dzung Dinh/VID_20250422_170009.mp4', $video_datetime, Overwrite => 1);
$exiftool->SetVideoDateTime('C:/Users/mbirk/exiftoolplus/_test/Test_Video_DJI.mp4', $video_datetime, Overwrite => 1);
# $exiftool->SetVideoDateTime('C:/Users/mbirk/Downloads/Test_Video_Samsung.mp4', $video_datetime);
# $exiftool->PrintTagsToFile('C:/Users/mbirk/Downloads/Test_Video_Samsung.mp4', DateTime => 1);


my $photo_datetime = DateTime->new(
    year       => 2025,
    month      => 4,
    day        => 21,
    hour       => 13,
    minute     => 52,
    second     => 0,
    nanosecond => 0,
    time_zone  => '-0400',
);
# $exiftool->SetPhotoDateTime('C:/Users/mbirk/Desktop/Marathon Photos/Boston 2025/861650_1009_0036.jpg', $photo_datetime, Overwrite => 1);
# $exiftool->SetPhotoDateTime('C:/Users/mbirk/Downloads/20250421_boston-globe.jpg', $photo_datetime, Overwrite => 1);
