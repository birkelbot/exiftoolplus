#!/usr/bin/perl
use strict;
use warnings;

use lib '.';

use DateTime::Format;
use DateTime::Parse;
use Image::ExifToolPlus;

my $exiftool = ExifToolPlus->new;

sub _get_updated_file {
  my ($file) = @_;
  my ($file_without_extension) = $file =~ m/(.*)\.[^\\\/]+$/;
  my ($file_extension) = $file =~ m/.*(\.[^\\\/]+)$/;
  return $file_without_extension . '_updated' . $file_extension;
}

# Correct setting of DateTimeOriginal from videos taken in different time zones ?
# https://exiftool.org/forum/index.php?topic=15057.0
sub test_rewrite_video_time_zone {
  my ($file, $time_zone) = @_;

  my $outfile = _get_updated_file($file);

  # # Copy the QuickTime:CreateDate tag into QuickTime:Keys:CreationDate and
  # # QuickTime:UserData:DateTimeOriginal, but with an added time zone.
  $exiftool->ExtractInfo($file);
  my $date_string = $exiftool->GetValue('QuickTime:CreateDate');
  print "date_string = $date_string\n";
  my $datetime = parse_datetime($date_string);
  $datetime->set_time_zone($time_zone);
  print 'format_datetime($datetime) = ' . format_datetime($datetime) . "\n";
  $exiftool->SetNewValue('QuickTime:Keys:CreationDate' => format_datetime($datetime));
  $exiftool->SetNewValue('QuickTime:UserData:DateTimeOriginal' => format_datetime($datetime));
  unlink($outfile);
  $exiftool->WriteInfo($file, $outfile);
  $exiftool->CheckError();
  print "Successfully wrote file: $outfile\n";
  get_and_write_tags_to_exif_txt_files(qq("$outfile"), DateTime => 1);
}
test_rewrite_video_time_zone('C:/Users/mbirk/PhotoVideoDateTime/_test/TESTING/Test_Video.mp4', '+1200');
