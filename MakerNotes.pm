package MakerNotes;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw( delete_samsung_makernotes );

sub _get_updated_file {
  my ($file) = @_;
  my ($file_without_extension) = $file =~ m/(.*)\.[^\\\/]+$/;
  my ($file_extension) = $file =~ m/.*(\.[^\\\/]+)$/;
  return $file_without_extension . '_updated' . $file_extension;
}

# See: Editing tags that claim to be non-writable by exiftool:
#   https://superuser.com/questions/1826169/is-it-possible-to-change-tags-that-are-not-writable-by-exiftool
# Source code where this tag is defined:
#   https://github.com/exiftool/exiftool/blob/master/lib/Image/ExifTool/Samsung.pm
%Image::ExifTool::UserDefined = (
  'Image::ExifTool::Samsung::Trailer' => {
    '0x0a01' => { # https://exiftool.org/forum/index.php?topic=7161
      Name => 'TimeStamp',
      Groups => { 2 => 'Time' },
      ValueConv => 'ConvertUnixTime($val / 1e3, 1, 3)',
      ValueConvInv => 'GetUnixTime($val, 1) * 1e3',
      PrintConv => '$self->ConvertDateTime($val)',
      PrintConvInv => '$self->InverseDateTime($val)',
      Writable => 'int16u',
    },
  },
);

# DOESN'T WORK. Still saving it for future reference.
sub modify_samsung_makernotes {
  my ($file) = @_;

  # DOESN'T WORK:
  $exiftool->SetNewValue('MakerNotes:Samsung:TimeStamp' => '2024:07:01 12:00:00.000-05:00');
  check_exiftool_error();

  my $outfile = _get_updated_file($file);
  unlink($outfile);
  $exiftool->WriteInfo($file, $outfile);
  check_exiftool_error();
  print("Successfully wrote file. Newly written file's tags:\n");

  my $tags_ref = $exiftool->ImageInfo($outfile);
  check_exiftool_error();
  foreach my $tag_key (sort {lc $a cmp lc $b} keys %$tags_ref) {
    my $tag_key_with_groups = $exiftool->GetGroup($tag_key, ':0:1:2:3') . ":$tag_key";
    check_exiftool_error();
    # Only print the tags in the MakerNotes:Samsung:Time group.
    next if ($tag_key_with_groups !~ m/MakerNotes:Samsung:Time/);
    print("  $tag_key_with_groups => $tags_ref->{$tag_key}\n");
  }
}

sub delete_samsung_makernotes {
  my ($file) = @_;

  # DOESN'T WORK:
  # $exiftool->SetNewValue('MakerNotes:Samsung:TimeStamp');
  # $exiftool->SetNewValue('MakerNotes:*');

  # See: trying to edit the MakerNotes:Samsung:Time:Main:TimeStamp tag
  #   https://exiftool.org/forum/index.php?topic=16109.0
  # This successfully deletes the MakerNotes:Samsung:Time:Main:TimeStamp tag.
  $exiftool->SetNewValue('Trailer:*');
  check_exiftool_error();

  my $outfile = _get_updated_file($file);
  unlink($outfile);
  $exiftool->WriteInfo($file, $outfile);
  check_exiftool_error();
  print("Successfully wrote file. Newly written file's tags:\n");

  my $tags_ref = $exiftool->ImageInfo($outfile);
  check_exiftool_error();
  foreach my $tag_key (sort {lc $a cmp lc $b} keys %$tags_ref) {
    my $tag_key_with_groups = $exiftool->GetGroup($tag_key, ':0:1:2:3') . ":$tag_key";
    check_exiftool_error();
    # Only print the tags in the MakerNotes:Samsung:Time group.
    next if ($tag_key_with_groups !~ m/MakerNotes:Samsung:Time/);
    print("  $tag_key_with_groups => $tags_ref->{$tag_key}\n");
  }
}

1;
