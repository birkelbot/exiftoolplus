package Image::ExifToolPlus;

use strict;
use warnings;
use Carp;

use DateTime::Format;
use File::Basename qw(basename fileparse);  # For robust filename handling
use File::Spec;  # For platform-independent path joining
use Image::ExifTool;
use Scalar::Util qw(blessed);  # To check if $datetime is a DateTime object

our @ISA = qw(Image::ExifTool);

# --- Constants for File Types ---
# Based on common FileType values from ExifTool
use constant {
    PHOTO_TYPES => {
        map { $_ => 1 } qw( JPEG PNG GIF TIFF HEIC CR2 NEF ARW DNG ORF
                            PEF RW2 SRW PSD JP2 BMP WEBP AVIF RAF XMP )
    },
    VIDEO_TYPES => {
        map { $_ => 1 } qw(
            MP4 MOV AVI M2TS MTS M4V 3GP 3G2 MPG MPEG MKV WEBM FLV WMV DV MP4V )
    },
};

# Creates a new Image::ExifToolPlus object.
#
# Arguments:
#   (passed to parent Image::ExifTool::new)
#
# Returns:
#   A blessed Image::ExifToolPlus object.
sub new {
  my $class = shift;

  # Call the parent's constructor using SUPER::.
  my $self = $class->SUPER::new(@_);

  # Re-bless the object into the wrapper class for correct method dispatch.
  bless $self, $class;

  # Set default options for this wrapper.
  $self->Options(LargeFileSupport => 1);

  return $self;
}

# Checks for errors or warnings from the last Image::ExifTool operation.
#
# Arguments:
#   (none - operates on the object $self)
#
# Returns:
#   $self (the object instance), allowing method chaining.
#
# Dies (croaks) if an Error tag is found.
# Warns (carps) if a Warning tag is found.
sub CheckError {
  my $self = shift;

  my $error = $self->GetValue('Error');
  my $warning = $self->GetValue('Warning');

  croak "EXIFTOOL ERROR: $error" if defined $error;
  carp "EXIFTOOL WARNING: $warning" if defined $warning;

  return $self;  # Return $self to allow method chaining CheckError
}

# ------------------------------------------------------------------------------
# Getting & Printing Tags
# ------------------------------------------------------------------------------

# Extracts tags from a file, with options for filtering.
#
# Arguments:
#   $file    - Path to the image file.
#   %options - Hash of options:
#               DateTime => 1 to only get the DateTime-related tags.
#
# Returns:
#   A hashref of processed tags { "Group - TagName" => Value, ... }.
#   Returns an empty hashref {} on failure (e.g., file not found, read error).
sub GetTags {
  my $self = shift;
  my ($file, %options) = @_;

  # Check if file exists and is readable.
  unless (-e $file && -r _) {
    carp "File not found or not readable: $file";
    return {};
  }

  my $tags_ref = $self->ImageInfo($file);
  # CheckError after ImageInfo, as it might set Error/Warning
  eval { $self->CheckError() };
  if ($@) {
    # If CheckError croaked, ImageInfo likely failed significantly
    carp "Failed to get image info for '$file': $@";
    return {};
  }

  my %output_tags;
  foreach my $tag_key (keys %$tags_ref) {

    # --- DateTime Filtering -----------------------------------------

    if ($options{DateTime}) {
      # Skip tags not related to date/time based on name.
      next if ($tag_key !~ m/date|time/i);
      # Skip specific date/time tags not related to photo/video timestamp.
      next if (
           $tag_key =~ m/^(?:CurrentTime|ExposureTime|PosterTime|PreviewTime)$/i
        || $tag_key =~ m/^(?:ProfileDateTime|MediaTimeScale|SelectionTime)$/i
        || $tag_key =~ m/^(?:SensorReadoutTime|TimeCode|TimeScale)$/i
      );
    }

    # --- Tag Processing ---------------------------------------------

    # Include group families 0-3 for context and disambiguation.
    # See: https://exiftool.org/TagNames/.
    my $tag_group = $self->GetGroup($tag_key, ':0:1:2:3');

    # Remove potential tag copy numbers.
    my ($tag_key_without_copy_num) = $tag_key =~ m/^([\S]+)/;
    # Fallback if the regex somehow fails.
    $tag_key_without_copy_num //= $tag_key;

    my $output_key = "$tag_group - $tag_key_without_copy_num";

    $output_tags{$output_key} = $tags_ref->{$tag_key};
  }

  # Returning a reference to the hash is more performant:
  #   https://www.perlmonks.org/?node_id=216232
  return \%output_tags;
}

# For each file in a fileglob, gets the metadata tags and prints them to a text
# file named "<original_filename>_tags.txt" in the same directory.
#
# Arguments:
#   $fileglob - Glob pattern (e.g., "*.jpg", "/path/to/images/*.*").
#               Remember to double quote globs with spaces:
#               https://stackoverflow.com/questions/32260485.
#   %options  - Hash of options (passed directly to GetTags():
#                 DateTime => 1 to only get the DateTime-related tags.
#
# Returns:
#   The number of files successfully processed.
sub PrintTagsToFile {
  my $self = shift;
  my ($fileglob, %options) = @_;

  my @files = glob($fileglob);
  unless (@files) {
    carp "No files found matching glob pattern: $fileglob";
    return 0;
  }

  my $processed_count = 0;
  foreach my $file (@files) {
    # Skip directories that might match the glob.
    next unless -f $file;

    # --- File Type Check --------------------------------------------
    # Get FileType to ensure we only process supported media files.
    my $info = $self->ImageInfo($file, 'FileType');
    # Check for errors getting basic info.
    eval { $self->CheckError() };
    if ($@) {
        carp "Skipping file '$file' due to error reading info: $@";
        next;
    }
    unless ($info && exists $info->{FileType}) {
        carp "Skipping file '$file': Could not determine FileType.";
        next;
    }
    my $file_type = $info->{FileType};
    unless (exists PHOTO_TYPES->{$file_type}
              || exists VIDEO_TYPES->{$file_type}) {
        next;   # Silently skip unsupported types.
    }
    # --- End File Type Check ----------------------------------------

    my $tags_ref = $self->GetTags($file, %options);

    # Skip if GetTags returned nothing useful or encountered an error.
    next unless (ref $tags_ref eq 'HASH' && keys %$tags_ref);

    # --- Output File Handling ---------------------------------------

    # Get filename without extension, using File::Basename for reliability.
    my ($filename, $directory, $suffix) = fileparse($file, qr/\.[^.]*/);
    my $output_basename = $filename . '_tags.txt';
    # Use File::Spec to join directory and filename correctly on any OS.
    my $output_filename = File::Spec->catfile($directory, $output_basename);

    my $outfile;
    unless (open($outfile, '>:encoding(UTF-8)', $output_filename)) {
      carp "Cannot open output file '$output_filename': $!";
      next;  # Skip to the next file
    }

    # --- Writing Tags -----------------------------------------------

    # Print the tags in sorted order.
    # See: https://perlmaven.com/how-to-sort-a-hash-in-perl
    foreach my $tag_key (sort {lc $a cmp lc $b} keys %$tags_ref) {
      my $value = $tags_ref->{$tag_key};
      # Indent multi-line strings, but skip scalar refs so we don't accidentally
      # corrupt binary data.
      $value =~ s/\n/\n        /g if ref $value ne 'SCALAR';

      # Syntax for printing to a file handle: 
      #   https://stackoverflow.com/q/13659186
      print $outfile "$tag_key => $value\n";
    }

    unless (close($outfile)) {
      carp "Error closing output file '$output_filename': $!";
    } else {
      $processed_count++;
    }
  }

  return $processed_count;
}

# ------------------------------------------------------------------------------
# Setting DateTime on Photos/Videos
# ------------------------------------------------------------------------------

# Internal helper to generate the '_updated' filename.
#
# Arguments:
#   $file - Original filename.
#
# Returns:
#   Filename with '_updated' appended before the extension.
sub _get_updated_file {
  my $self = shift;
  my ($file) = @_;

  # Use File::Basename for robustness.
  my ($filename, $directory, $suffix) = fileparse($file, qr/\.[^.]*/);
  my $updated_basename = $filename . '_updated' . $suffix;
  # Use File::Spec for cross-platform compatibility.
  return File::Spec->catfile($directory, $updated_basename);
}

# Internal helper to set various date/time tags for a photo file.
#
# Arguments:
#   $file     - Path to the photo file.
#   $datetime - DateTime object.
#   %options  - Hash of options:
#                 Overwrite => 1 to modify the file in place.
#                              Otherwise, creates '_updated' copy.
#
# Returns:
#   1 if the file was successfully written to.
#   0 if the file was not written (no changes needed, WriteInfo returned 0).
#   undef on error during write.
sub _set_photo_datetime {
  my $self = shift;
  my ($file, $datetime, %options) = @_;

  my $datetime_no_subsec =
      DateTime::Format::format_datetime($datetime, OmitSubSec => 1);
  my $datetime_no_tz =
      DateTime::Format::format_datetime($datetime, OmitTimeZone => 1);
  my $datetime_no_subsec_no_tz =
      DateTime::Format::format_datetime(
        $datetime, OmitSubSec => 1, OmitTimeZone => 1);
  my $datetime_incl_subsec =
      DateTime::Format::format_datetime($datetime, ForceIncludeSubSec => 1);
  my $datetime_incl_subsec_no_tz =
      DateTime::Format::format_datetime(
        $datetime, ForceIncludeSubSec => 1, OmitTimeZone => 1);
  my $time_zone_str = DateTime::Format::extract_formatted_timezone($datetime);

  # --- Unconditional Writes -----------------------------------------
  # These tags are key tags used by many apps. We also want to include the time
  # zone information on all photos.
  $self->SetNewValue('EXIF:ExifIFD:CreateDate', $datetime_no_subsec_no_tz);
  $self->SetNewValue(
    'EXIF:ExifIFD:DateTimeOriginal', $datetime_no_subsec_no_tz);
  $self->SetNewValue('EXIF:ExifIFD:OffsetTimeDigitized', $time_zone_str);
  $self->SetNewValue('EXIF:ExifIFD:OffsetTimeOriginal', $time_zone_str);

  # --- Conditional Writes -------------------------------------------
  # Use EditOnly => 1 to write only if the tag already exists.
  $self->SetNewValue(
    'Composite:SubSecCreateDate', $datetime_incl_subsec_no_tz, EditOnly => 1);
  $self->SetNewValue(
    'Composite:SubSecDateTimeOriginal', $datetime_incl_subsec, EditOnly => 1);
  $self->SetNewValue(
    'Composite:SubSecModifyDate', $datetime_incl_subsec, EditOnly => 1);
  $self->SetNewValue(
    'EXIF:ExifIFD:ModifyDate',
    $datetime_no_subsec_no_tz, EditOnly => 1
  );
  $self->SetNewValue('EXIF:ExifIFD:OffsetTime', $time_zone_str, EditOnly => 1);
  $self->SetNewValue('EXIF:IFD0:ModifyDate', $datetime_no_tz, EditOnly => 1);
  $self->SetNewValue(
    'File:System:FileCreateDate', $datetime_no_subsec,
    Protected => 1, EditOnly => 1);
  $self->SetNewValue(
    'File:System:FileModifyDate', $datetime_no_subsec,
    Protected => 1, EditOnly => 1);
  $self->SetNewValue('PNG:PNG:CreateDate', $datetime_no_subsec, EditOnly => 1);
  $self->SetNewValue(
    'PNG:PNG:CreationTime', $datetime_no_subsec, EditOnly => 1);
  $self->SetNewValue('PNG:PNG:ModifyDate', $datetime_no_subsec, EditOnly => 1);
  $self->SetNewValue(
    'XMP:XMP-exif:DateTimeOriginal', $datetime_no_subsec, EditOnly => 1);
  $self->SetNewValue(
    'XMP:XMP-xmp:CreateDate', $datetime_no_subsec, EditOnly => 1);
  $self->SetNewValue(
    'XMP:XMP-xmp:ModifyDate', $datetime_no_subsec, EditOnly => 1);

  # --- SubSecTime Handling --------------------------------
  # EditOnly Logic:
  # - If subseconds were provided, EditOnly=FALSE(0).
  #   Forces create/overwrite with the new subsecond value.
  # - If subseconds were NOT provided, EditOnly=TRUE(1).
  #   Only writes (sets to '000') if the tag *already exists*.
  my $sub_sec_edit_only = $datetime->millisecond == 0;
  # Format subseconds as a string with 3 digits.
  my $sub_sec_value = sprintf("%03d", $datetime->millisecond);

  $self->SetNewValue(
    'EXIF:ExifIFD:SubSecTime', $sub_sec_value, EditOnly => $sub_sec_edit_only);
  $self->SetNewValue(
    'EXIF:ExifIFD:SubSecTimeDigitized',
    $sub_sec_value, EditOnly => $sub_sec_edit_only
  );
  $self->SetNewValue(
    'EXIF:ExifIFD:SubSecTimeOriginal',
    $sub_sec_value, EditOnly => $sub_sec_edit_only
  );
  # --- End SubSecTime Handling ----------------------------

  # Check for errors from SetNewValue calls before attempting write.
  eval { $self->CheckError() };
  if ($@) {
      carp "Error preparing tags for photo '$file': $@";
      return undef;  # Indicate error.
  }

  my $result;
  my $outfile = $file;
  if ($options{Overwrite}) {
    $result = $self->WriteInfo($file);
  } else {
    my $outfile = $self->_get_updated_file($file);
    # Attempt to remove existing output file, warn if it fails but continue
    if (-e $outfile) {
        unless (unlink($outfile)) {
            carp "Could not delete existing output file '$outfile': $!";
        }
    }
    $result = $self->WriteInfo($file, $outfile);
  }

  eval { $self->CheckError() };
  if ($@) {
      carp "Error writing tags to photo '$outfile': $@";
      return undef;  # Indicate error.
  }

  # WriteInfo returns: 1 on success, 0 if no changes, undef on error.
  # We return 1 only if the file was actually modified.
  return (defined $result && $result == 1) ? 1 : 0;
}

# Internal helper to set various date/time tags for a video file.
#
# Arguments:
#   $file     - Path to the video file.
#   $datetime - DateTime object.
#   %options  - Hash of options:
#                 Overwrite => 1 to modify the file in place.
#                              Otherwise, creates '_updated' copy.
#
# Returns:
#   1 if the file was successfully written to.
#   0 if the file was not written (no changes needed, WriteInfo returned 0).
#   undef on error during write.
sub _set_video_datetime {
  my $self = shift;
  my ($file, $datetime, %options) = @_;

  my $datetime_local = DateTime::Format::format_datetime($datetime);
  my $datetime_local_no_subsec =
      DateTime::Format::format_datetime($datetime, OmitSubSec => 1);
  my $datetime_utc =
      DateTime::Format::format_datetime($datetime, ConvertToUTC => 1);

  # --- Unconditional Writes -----------------------------------------
  # These tags are key tags used by many apps. We also want to include the time
  # zone information on all videos.
  $self->SetNewValue('QuickTime:Keys:CreationDate', $datetime_local);
  $self->SetNewValue('QuickTime:UserData:DateTimeOriginal', $datetime_local);
  $self->SetNewValue(
    'XMP:XMP-exif:DateTimeOriginal', $datetime_local_no_subsec);
  $self->SetNewValue('XMP:XMP-xmp:CreateDate', $datetime_local_no_subsec);

  # --- Conditional Writes -------------------------------------------
  # Use EditOnly => 1 to write only if the tag already exists.
  $self->SetNewValue(
    'File:System:FileCreateDate', $datetime_local,
    Protected => 1, EditOnly => 1
  );
  $self->SetNewValue(
    'File:System:FileModifyDate', $datetime_local,
    Protected => 1, EditOnly => 1
  );
  $self->SetNewValue('QuickTime:CreateDate', $datetime_utc, EditOnly => 1);
  $self->SetNewValue('QuickTime:ModifyDate', $datetime_utc, EditOnly => 1);
  $self->SetNewValue(
    'XMP:XMP-xmp:ModifyDate', $datetime_local_no_subsec, EditOnly => 1);

  # --- Track DateTimes (Conditional) --------------------------------
  # These often exist in multiple tracks. Only update if already present.
  my @track_base_tags = (
    'MediaCreateDate',
    'MediaModifyDate',
    'TrackCreateDate',
    'TrackModifyDate',
  );
  foreach my $base_tag (@track_base_tags) {
      # Let ExifTool find the tag in any track (Track1, Track2, etc.).
      $self->SetNewValue(
        $base_tag => $datetime_utc, EditOnly => 1, Group => 'QuickTime');
  }

  # Check for errors from SetNewValue calls before attempting write.
  eval { $self->CheckError() };
  if ($@) {
      carp "Error preparing tags for video '$file': $@";
      return undef;  # Indicate error.
  }

  my $result;
  my $outfile = $file;
  if ($options{Overwrite}) {
    $result = $self->WriteInfo($file);
  } else {
    $outfile = $self->_get_updated_file($file);
     # Attempt to remove existing output file, warn if it fails but continue.
    if (-e $outfile) {
        unless (unlink($outfile)) {
            carp "Could not delete existing output file '$outfile': $!";
        }
    }
    $result = $self->WriteInfo($file, $outfile);
  }

  eval { $self->CheckError() };
  if ($@) {
      carp "Error writing tags to video '$outfile': $@";
      return undef; # Indicate error
  }

  # WriteInfo returns: 1 on success, 0 if no changes, undef on error.
  # We return 1 only if the file was actually modified.
  return (defined $result && $result == 1) ? 1 : 0;
}


# Sets date/time tags for multiple photo/video files based on a glob pattern.
# Determines file type and dispatches to appropriate internal method.
#
# Arguments:
#   $fileglob - Glob pattern (e.g., "*.jpg", "/path/to/media/*.*").
#               Remember to double quote globs with spaces.
#   $datetime - DateTime object representing the timestamp to set.
#   %options  - Hash of options:
#                 Overwrite      => 1 : Modify files in place.
#                                    Otherwise, creates '_updated' copies.
#                 VerboseLogging => 1 : Print messages for each updated file.
#
# Returns:
#   A hash reference containing counts:
#     { photos => N, videos => N, skipped => N }
#   Returns undef on major error (e.g., invalid DateTime object).
sub SetDateTime {
    my $self = shift;
    my ($fileglob, $datetime, %options) = @_;

    unless (blessed($datetime) && $datetime->isa('DateTime')) {
        carp "Invalid DateTime object passed to SetDateTime.";
        return undef;
    }

    my @files = glob($fileglob);
    unless (@files) {
        carp "No files found matching glob pattern: $fileglob";
        return { photos => 0, videos => 0, skipped => 0 };
    }

    my %counts = ( photos => 0, videos => 0, skipped => 0 );

    print "Starting DateTime update process...\n" if $options{VerboseLogging};

    foreach my $file (@files) {
        # Skip directories.
        next unless -f $file;

        # Get FileType to determine how to process.
        # Request only FileType to minimize overhead.
        my $info = $self->ImageInfo($file, 'FileType');
        # Check for errors getting basic info.
        eval { $self->CheckError() };
        if ($@) {
            carp "Skipping file '$file' due to error reading info: $@";
            $counts{skipped}++;
            next;
        }
        unless ($info && exists $info->{FileType}) {
            carp "Skipping file '$file': Could not determine FileType.";
            $counts{skipped}++;
            next;
        }

        my $file_type = $info->{FileType};
        my $update_status; # Will be 1 (updated), 0 (not updated), undef (error)

        if (exists PHOTO_TYPES->{$file_type}) {
            $update_status =
                $self->_set_photo_datetime($file, $datetime, %options);
            if (defined $update_status && $update_status == 1) {
                $counts{photos}++;
                print "Updated photo: $file\n" if $options{VerboseLogging};
            } elsif (!defined $update_status) {
                # Error occurred and was logged by _set_photo_datetime.
                $counts{skipped}++;
            } else {  # update_status == 0
                # File was processed, but no tags were changed.
                print "Skipped photo (no changes needed): $file\n"
                    if $options{VerboseLogging};
                $counts{skipped}++;
            }
        }
        elsif (exists VIDEO_TYPES->{$file_type}) {
            $update_status =
                $self->_set_video_datetime($file, $datetime, %options);
             if (defined $update_status && $update_status == 1) {
                $counts{videos}++;
                print "Updated video: $file\n" if $options{VerboseLogging};
            } elsif (!defined $update_status) {
                # Error occurred and was logged by _set_video_datetime.
                $counts{skipped}++;
            } else {  # update_status == 0
                # File was processed, but no tags were changed.
                print "Skipped video (no changes needed or error): $file\n"
                    if $options{VerboseLogging};
                $counts{skipped}++;
            }
        }
        else {
            carp "Skipping unsupported file type '$file_type': $file";
            $counts{skipped}++;
        }
    }

    # Print summary
    print "----------------------------------------\n";
    print "DateTime update process complete.\n";
    print "  Photos updated: $counts{photos}\n";
    print "  Videos updated: $counts{videos}\n";
    print "  Files skipped:  $counts{skipped}\n";
    print "----------------------------------------\n";

    return \%counts;
}

1;
