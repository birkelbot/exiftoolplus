#!/usr/bin/perl
use strict;
use warnings;

use DateTime;
use Image::ExifToolPlus;

my $exiftool = Image::ExifToolPlus->new;

sub create_photo_with_experimental_tags ($%) {
  my ($file, %options) = @_;

  # Start at 00:00 in UTC.
  my $datetime = DateTime->new(
      year       => 2024,
      month      => 8,
      day        => 2,
      hour       => 5,
      minute     => 0,
      second     => 0,
      nanosecond => 1e6,
      time_zone  => '-0500',
  );
  # Set up each tag to be different by one hour. This will allow us to see what various software
  # uses as the "source of truth" for the photo timestamp.
  $exiftool->SetNewValue('Composite:Composite:SubSecCreateDate' => format_datetime($datetime->add(hours => 1), ForceIncludeSubSec => 1, OmitTimeZone => 1), EditOnly => 1);
  $exiftool->SetNewValue('Composite:Composite:SubSecDateTimeOriginal' => format_datetime($datetime->add(hours => 1),  ForceIncludeSubSec => 1), EditOnly => 1);
  $exiftool->SetNewValue('Composite:Composite:SubSecModifyDate' => format_datetime($datetime->add(hours => 1), ForceIncludeSubSec => 1), EditOnly => 1);
  $exiftool->SetNewValue('EXIF:ExifIFD:CreateDate' => format_datetime($datetime->add(hours => 1), OmitSubSec => 1, OmitTimeZone => 1), EditOnly => 1);
  $exiftool->SetNewValue('EXIF:ExifIFD:DateTimeOriginal' => format_datetime($datetime->add(hours => 1), OmitSubSec => 1, OmitTimeZone => 1), EditOnly => 1);
  $exiftool->SetNewValue('EXIF:ExifIFD:OffsetTime' => '-05:00', EditOnly => 1);
  $exiftool->SetNewValue('EXIF:ExifIFD:OffsetTimeOriginal' => '-05:00', EditOnly => 1);
  $exiftool->SetNewValue('EXIF:ExifIFD:SubSecTime' => '100', EditOnly => 1);
  $exiftool->SetNewValue('EXIF:ExifIFD:SubSecTimeDigitized' => '100', EditOnly => 1);
  $exiftool->SetNewValue('EXIF:ExifIFD:SubSecTimeOriginal' => '100', EditOnly => 1);
  $exiftool->SetNewValue('EXIF:IFD0:ModifyDate' => format_datetime($datetime->add(hours => 1), OmitTimeZone => 1), EditOnly => 1);
  $exiftool->SetNewValue('File:System:FileCreateDate' => format_datetime($datetime->add(hours => 1), OmitSubSec => 1), Protected => 1, EditOnly => 1);
  $exiftool->SetNewValue('File:System:FileModifyDate' => format_datetime($datetime->add(hours => 1), OmitSubSec => 1), Protected => 1, EditOnly => 1);
  $exiftool->SetNewValue('XMP:XMP-xmp:CreateDate' => format_datetime($datetime->add(hours => 1), OmitSubSec => 1), EditOnly => 1);
  $exiftool->SetNewValue('XMP:XMP-xmp:ModifyDate' => format_datetime($datetime->add(hours => 1), OmitSubSec => 1), EditOnly => 1);
  $exiftool->CheckError();

  if ($options{Overwrite}) {
    $exiftool->WriteInfo($file);
    $exiftool->CheckError();
    $exiftool->PrintTagsToFile(qq("$file"), DateTime => 1);
  } else {
    my $outfile = get_updated_file($file);
    unlink($outfile);
    $exiftool->WriteInfo($file, $outfile);
    $exiftool->CheckError();
    $exiftool->PrintTagsToFile(qq("$outfile"), DateTime => 1);
  }
}
# create_photo_with_experimental_tags('C:/Users/mbirk/PhotoVideoDateTime/_test/TESTING/Updated/Test_Photo_DJI_updated.jpg', Overwrite => 1);
# create_photo_with_experimental_tags('C:/Users/mbirk/PhotoVideoDateTime/_test/TESTING/Updated/Test_Photo_GoPro_updated.jpg', Overwrite => 1);
# create_photo_with_experimental_tags('C:/Users/mbirk/PhotoVideoDateTime/_test/TESTING/Updated/Test_Photo_Samsung2_updated.jpg', Overwrite => 1);
# create_photo_with_experimental_tags('C:/Users/mbirk/PhotoVideoDateTime/_test/TESTING/Originals/Test_Photo_Samsung.jpg');

sub create_video_with_experimental_tags ($%) {
  my ($file, %options) = @_;

  # Start at 00:00 in UTC.
  my $datetime = DateTime->new(
      year       => 2024,
      month      => 8,
      day        => 1,
      hour       => 5,
      minute     => 0,
      second     => 0,
      nanosecond => 0,
      time_zone  => '-0500',
  );
  # Set up each tag to be different by one hour. This will allow us to see what various software
  # uses as the "source of truth" for the video timestamp.
  $exiftool->SetNewValue('File:System:FileCreateDate' => format_datetime($datetime->add(hours => 1)), Protected => 1, EditOnly => 1);
  $exiftool->SetNewValue('File:System:FileModifyDate' => format_datetime($datetime->add(hours => 1)), Protected => 1, EditOnly => 1);
  # NOTE: For the experiment to see which fields get updated by Windows Photos, we need to comment
  # out this line. When a video has 'QuickTime:Keys:CreationDate', Windows Photos refuses to let you
  # edit the datetime.
  $exiftool->SetNewValue('QuickTime:Keys:CreationDate' => format_datetime($datetime->add(hours => 1)));
  $exiftool->SetNewValue('QuickTime:CreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:ModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track1:MediaCreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track1:MediaModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track1:TrackCreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track1:TrackModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track2:MediaCreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track2:MediaModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track2:TrackCreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track2:TrackModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track3:MediaCreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track3:MediaModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track3:TrackCreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track3:TrackModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track4:MediaCreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track4:MediaModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track4:TrackCreateDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  $exiftool->SetNewValue('QuickTime:Track4:TrackModifyDate' => format_datetime($datetime->add(hours => 1), ConvertToUTC => 1), EditOnly => 1);
  # NOTE: For the experiment to see which fields get updated by Windows Photos, we need to comment
  # out this line. When a video has 'QuickTime:Keys:CreationDate', Windows Photos refuses to let you
  # edit the datetime.
  $exiftool->SetNewValue('QuickTime:UserData:DateTimeOriginal' => format_datetime($datetime->add(hours => 1)));
  $exiftool->CheckError;

  if ($options{Overwrite}) {
    $exiftool->WriteInfo($file);
    $exiftool->CheckError;
    $exiftool->PrintTagsToFile(qq("$file"), DateTime => 1);
  } else {
    my $outfile = get_updated_file($file);
    unlink($outfile);
    $exiftool->WriteInfo($file, $outfile);
    $exiftool->CheckError;
    $exiftool->PrintTagsToFile(qq("$outfile"), DateTime => 1);
  }
}
# create_video_with_experimental_tags('C:/Users/mbirk/PhotoVideoDateTime/_test/TESTING/Originals/Test_Video_DJI.mp4');
