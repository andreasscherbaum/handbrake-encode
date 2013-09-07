#!/usr/bin/env perl
#
#
# rip videos from DVDs using Handbrake
#
# for information about Handbrake see: http://www.handbrake.fr/
#
#
# written by Andreas 'ads' Scherbaum <ads@wars-nicht.de>
#
# history:
#  2013-01-12                initial version
#
#
# license: New BSD License
#
#
# Copyright (c) 2013, Andreas Scherbaum
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of Andreas Scherbaum nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL Andreas Scherbaum BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.



# wrapper around Handbrake
package handbrake;

use strict;
use warnings;
use POSIX;
use Data::Dumper;
use FileHandle;



# new()
#
# constructor
#
# parameter:
#  - class name
# return:
#  - pointer to config class
sub new {
    my $class = shift;

    my $self = {};
    # bless mysqlf
    bless($self, $class);
    # define own variables

    # HandBrakeCLI
    $self->{handbrake} = undef;
    # DVD device
    $self->{device} = undef;
    # minimal time for tracks
    $self->{min_track_time} = 0;
    # maximal time for tracks
    $self->{max_track_time} = undef;

    # return reference
    return $self;
}


# set_handbrake()
#
# set handbrake path (required)
#
# parameter:
#  - reference
#  - handbrake path
# return:
#  none
sub set_handbrake {
    my $self = shift;
    my $handbrake = shift;

    if (!-x $handbrake) {
        print STDERR "handbrake path ($handbrake) is not an executable\n";
        exit(1);
    }
    $self->{handbrake} = $handbrake;
}


# set_device()
#
# set DVD device path (required)
#
# parameter:
#  - reference
#  - DVD device path
# return:
#  none
sub set_device {
    my $self = shift;
    my $device = shift;

    if (!-b $device) {
        print STDERR "DVD device ($device) is not a block device\n";
        exit(1);
    }
    $self->{device} = $device;
}


# set_min_track_time()
#
# set the minimum time for a track
#
# parameter:
#  - reference
#  - minimum time (in seconds)
# return:
#  none
# note:
#  - defaults to '0' (all tracks)
sub set_min_track_time {
    my $self = shift;
    my $time = shift;

    if ($time !~ /^\d+$/) {
        print STDERR "time ($time) is not an integer\n";
        exit(1);
    }
    $self->{min_track_time} = $time;
}


# set_max_track_time()
#
# set the maximum time for a track
#
# parameter:
#  - reference
#  - maximum time (in seconds), or undef
# return:
#  none
# note:
#  - defaults to 'undef' (all tracks)
sub set_max_track_time {
    my $self = shift;
    my $time = shift;

    if (defined($time) and $time !~ /^\d+$/) {
        print STDERR "time ($time) is not an integer\n";
        exit(1);
    }
    # allow undefined values
    $self->{max_track_time} = $time;
}


# scan()
#
# scan the DVD in the device and return hash with information
#
# parameter:
#  - reference
# return:
#  - hash with information
sub scan {
    my $self = shift;

    $self->prechecks();

    my $scan_result = $self->handbrake('--scan');
    #print "" . $scan_result . "\n";


    my %results = ();
    my $scan_result_tmp = $scan_result;
    $scan_result_tmp =~ s/[\r\n]+/ /gs;


    # DVD region
    if ($scan_result_tmp =~ /\. Regions: (\d)/) {
        $results{'region'} = $1;
    }

    # DVD Name
    if ($scan_result_tmp =~ /DVD Title: (.+?)[ ]+libdvdnav:/) {
        $results{'dvd_title'} = $1;
        print "DVD title: " . $results{'dvd_title'} . "\n";
    }

    # DVD Serial Number
    if ($scan_result_tmp =~ /DVD Serial Number: ([a-z0-9]+)/) {
        $results{'serial_number'} = $1;
    }

    if ($scan_result !~ /scan: DVD has (\d+) title/) {
        print STDERR "Could not identify the number of titles on the DVD\n";
        $self->write_debug_output($scan_result);
        exit(1);
    }
    $results{'number_titles'} = $1;
    $results{'real_number_titles'} = $1;
    print "number of titles: " . $results{'number_titles'} . "\n";
    $results{'titles'} = {};


    # scan all tracks
    for (my $title_nr = 1; $title_nr <= $results{'number_titles'}; $title_nr++) {
        print "scanning title number: $title_nr\n";
        my $scan_result_nr = $self->handbrake('--scan --title ' . $title_nr);

        my $scan_result_nr_tmp = $scan_result_nr;
        $scan_result_nr_tmp =~ s/[\r\n]+/ /gs;

        $results{'titles'}{$title_nr} = {};
        if ($scan_result_nr_tmp =~ /scan: duration is (\d\d):(\d\d):(\d\d) /) {
            $results{'titles'}{$title_nr}{'duration'} = $1 * 3600 + $2 * 60 + $1;
            #print "duration: " . $results{'titles'}{$title_nr}{'duration'} . " (" . $self->{min_track_time} . " - " . $self->{max_track_time} . ")\n";
        } else {
            print STDERR "Could not identify track duration time\n";
            $self->write_debug_output($scan_result);
            exit(1);
        }
        if ($results{'titles'}{$title_nr}{'duration'} < $self->{min_track_time}) {
            print "Skipping track $title_nr: track too short (" . main::formatted_time($results{'titles'}{$title_nr}{'duration'}) . ")\n";
            delete($results{'titles'}{$title_nr});
            $results{'real_number_titles'}--;
            next;
        }
        if (defined($self->{max_track_time}) and $results{'titles'}{$title_nr}{'duration'} > $self->{max_track_time}) {
            print "Skipping track $title_nr: track too long (" . main::formatted_time($results{'titles'}{$title_nr}{'duration'}) . ")\n";
            delete($results{'titles'}{$title_nr});
            $results{'real_number_titles'}--;
            next;
        }
        print "Track $title_nr length: " . main::formatted_time($results{'titles'}{$title_nr}{'duration'}) . "\n";

        # parse audio tracks
        my $audio_track = 1;
        my $audio_track_stop = 0;
        $results{'titles'}{$title_nr}{'audio'} = {};
        do {
            if ($scan_result_nr_tmp =~ /scan: checking audio $audio_track[ ]+.+?lang=([^,]+), 3cc=([a-z0-9]+)/s) {
                $results{'titles'}{$title_nr}{'audio'}{$audio_track} = {};
                $results{'titles'}{$title_nr}{'audio'}{$audio_track}{'lang'} = $1;
                $results{'titles'}{$title_nr}{'audio'}{$audio_track}{'3cc'} = $2;
                #print "Found audio: " . $results{'titles'}{$title_nr}{'audio'}{$audio_track}{'3cc'} . " for title: " . $audio_track . "\n";
                $audio_track++;
            } else {
                $audio_track_stop = 1;
            }
        } until ($audio_track_stop == 1);

        # parse subtitle tracks
        my $subtitle_track = 1;
        my $subtitle_track_stop = 0;
        $results{'titles'}{$title_nr}{'subtitle'} = {};
        do {
            if ($scan_result_nr_tmp =~ /scan: checking subtitle $subtitle_track[ ]+.+?lang=([^,]+), 3cc=([a-z0-9]+)/s) {
                $results{'titles'}{$title_nr}{'subtitle'}{$subtitle_track} = {};
                $results{'titles'}{$title_nr}{'subtitle'}{$subtitle_track}{'lang'} = $1;
                $results{'titles'}{$title_nr}{'subtitle'}{$subtitle_track}{'3cc'} = $2;
                #print "Found subtitle: " . $results{'titles'}{$title_nr}{'subtitle'}{$subtitle_track}{'3cc'} . " for title: " . $subtitle_track . "\n";
                $subtitle_track++;
            } else {
                $subtitle_track_stop = 1;
            }
        } until ($subtitle_track_stop == 1);


    }

    return \%results;
}


# encode()
#
# encode a track
#
# parameter:
#  - reference
#  - track number (title number)
#  - name of the output file
#  - format (m4v, mkv)
#  - list with audio tracks
#  - list with subtitle tracks
# return:
#  none
sub encode {
    my $self = shift;
    my $title = shift;
    my $name = shift;
    my $format = shift;
    my $audio = shift;
    my $subtitle = shift;
    my $preset = shift;

    $self->prechecks();

    my $exec = '--output "' . $name . '"';
    $exec .= ' --format ' . $format;
    $exec .= ' --markers';
    $exec .= ' --title ' . $title;
    if (defined($preset) and length($preset) > 0) {
        $exec .= ' --preset="' . $preset . '"';
        # the HandBrakeCLI which is shipped with Ubuntu 12.10 is crashing because the default encoder 'faac' is not available:
        #   ERROR: Invalid audio codec: 0x100
        #   Segmentation fault (core dumped)
        # switch to another encoder
        $exec .= ' -E ffaac';
    } else {
        $exec .= ' --keep-display-aspect';
        $exec .= ' --encoder x264';
    }
    $exec .= ' --previews 30';
    if (length($audio) > 0) {
        $exec .= ' --audio "' . $audio . '"';
    }
    if (length($subtitle) > 0) {
        $exec .= ' --subtitle "' . $subtitle . '"';
    }

    #print "exec: $exec\n";
    $self->handbrake($exec);

}


# prechecks()
#
# run some prechecks if requirements are met
#
# parameter:
#  - reference
# return:
#  none
sub prechecks {
    my $self = shift;

    if (!defined($self->{handbrake})) {
        print STDERR "handbrake executable not configured\n";
        exit(1);
    }
    if (!defined($self->{device})) {
        print STDERR "DVD device not configured\n";
        exit(1);
    }

}


# handbrake()
#
# run a handbrake job
#
# parameter:
#  - reference
#  - additional shell options
# return:
#  - handbrake output
sub handbrake {
    my $self = shift;
    my $options = shift;

    $self->prechecks();

    my $handbrake = $self->{handbrake};
    my $device = $self->{device};

    my $exec = $handbrake . ' ' . $options . ' ' . '--input ' . $device . ' 2>&1';
    #print "exec: $exec\n";
    my $result = `$exec`;
    my $exit_status = $?;
    my $exit_text = $!;

    if ($exit_status != 0) {
        print STDERR "Failed to execute handbrake\n";
        print STDERR "Error: $exit_text\n";
        print STDERR "Commandline: $exec\n";
        exit(1);
    }

    return $result;
}


# write_debug_output()
#
# write the handbrake output into a file in /tmp, for debugging
#
# parameter:
#  - reference
#  - output text
# return:
#  none
sub write_debug_output {
    my $self = shift;
    my $text = shift;

    my $fh = new FileHandle;
    my $file = '/tmp/handbrake-debug-' . $$ . '-' . time() . '.txt';
    if (!open($fh, ">", $file)) {
        print STDERR "Cannot open debug file\n";
        print STDERR "Error: $!\n";
        print STDERR "File: $file\n";
        return;
    }
    print $fh $text;
    close($fh);
    print STDERR "Wrote debug output to: $file\n";
}




# finish module
1;


package main;
use strict;
use warnings;
use POSIX;
use Getopt::Long qw( :config no_ignore_case );
use FileHandle;
use Data::Dumper;
use Config::Simple;
use File::Which;
import handbrake;




######################################################################
# handle command line arguments
######################################################################
# defaults

$main::config = new Config::Simple(syntax => 'ini');

# set default values
$main::config->param('debug.enabled', '0');
$main::config->param('device.name', '');
$main::config->param('device.eject', '0');
$main::config->param('time.display', '0');

# read in config file
if (-f ($ENV{'HOME'} . '/.handbrake-encode.conf')) {
    if (!$main::config->read($ENV{'HOME'} . '/.handbrake-encode.conf')) {
        print STDERR "Failed to read config file: $!\n";
        exit(1);
    }
}


# parse command line options
unless (
    GetOptions(
        'help|h|?'     => sub { help(); exit(0); },
        'debug'        => sub { $main::config->param('debug.enabled', '1') },
        'device|d=s'   => sub { $main::config->param('device.name', $_[1]); },
        'min-time=s'   => sub { $main::config->param('time.min-time', $_[1]); },
        'max-time=s'   => sub { $main::config->param('time.max-time', $_[1]); },
        'name=s'       => sub { $main::config->param('name.name', $_[1]); },
        'continue|c'   => sub { $main::config->param('name.continue', '1') },
        'format=s'     => sub { $main::config->param('name.format', $_[1]); },
        'audio=s'      => sub { $main::config->param('audio.languages', $_[1]); },
        'subtitle=s'   => sub { $main::config->param('subtitle.languages', $_[1]); },
        'eject|e'      => sub { $main::config->param('device.eject', $_[1]); },
        'eject-path=s' => sub { $main::config->param('device.eject-path', $_[1]); },
        'time|t'       => sub { $main::config->param('time.display', $_[1]); },
        'preset=s'     => sub { $main::config->param('presets.preset', $_[1]); },
    )
) {
    # There were some errors with parsing command line options - show help.
    help();
    exit(1);
}

if (!-b $main::config->param('device.name')) {
    print STDERR "DVD device name is not set\n";
    exit(1);
}

# look for 'HandBrakeCLI'
$main::handbrakecli = undef;
if (defined($main::config->param('device.HandBrakeCLI')) and length($main::config->param('device.HandBrakeCLI')) > 0) {
    if (!-x $main::config->param('device.HandBrakeCLI')) {
        print STDERR "HandBrakeCLI setting (" . $main::config->param('device.HandBrakeCLI') . ") is invalid\n";
        exit(1);
    }
    $main::handbrakecli = $main::config->param('device.HandBrakeCLI');
}
if (!defined($main::handbrakecli)) {
    my $which = which('HandBrakeCLI');
    if (!defined($which)) {
        print STDERR "Can't find the 'HandBrakeCLI' program in your \$PATH\n";
        exit(1);
    }
    $main::handbrakecli = $which;
}
if (!defined($main::handbrakecli)) {
    print STDERR "Was not able to identify a working 'HandBrakeCLI'\n";
    exit(1);
}

# look for eject program
$main::eject = undef;
if ($main::config->param('device.eject') == 1) {
    if (defined($main::config->param('device.eject-path')) and length($main::config->param('device.eject-path')) > 0) {
        if (!-x $main::config->param('device.eject-path')) {
            print STDERR "eject-path setting (" . $main::config->param('device.eject-path') . ") is invalid\n";
            exit(1);
        }
        $main::eject = $main::config->param('device.eject-path');
    }
    if (!defined($main::eject)) {
        my $which = which('eject');
        if (!defined($which)) {
            print STDERR "Can't find the 'eject' program in your \$PATH\n";
            exit(1);
        }
        $main::eject = $which;
    }
    if (!defined($main::eject)) {
        print STDERR "Was not able to identify a working 'eject'\n";
        exit(1);
    }
}


if (!defined($main::config->param('name.name')) or length($main::config->param('name.name')) < 1) {
    print STDERR "Desperately need a name for the output file\n";
    exit(1);
}

if ($main::config->param('name.format') ne 'm4v' and $main::config->param('name.format') ne 'mkv') {
    print STDERR "Output format must be either 'm4v' or 'mkv'\n";
    exit(1);
}



$main::handbrake = new handbrake;
$main::handbrake->set_handbrake($main::handbrakecli);
$main::handbrake->set_device($main::config->param('device.name'));

if (defined($main::config->param('time.min-time'))) {
    $main::handbrake->set_min_track_time($main::config->param('time.min-time'));
}
if (defined($main::config->param('time.max-time'))) {
    $main::handbrake->set_max_track_time($main::config->param('time.max-time'));
}


my $result = $main::handbrake->scan();
print "Found " . $result->{'number_titles'} . " titles on disk, " . $result->{'real_number_titles'} . " usable titles\n";



my $this_number = 0;
foreach my $title_nr (sort(keys(%{$result->{'titles'}}))) {
    $this_number++;
    print "Title: " . $title_nr . " (" . $this_number . " of " . $result->{'real_number_titles'} . ")\n";
    my $name = $main::config->param('name.name');
    my $format = $main::config->param('name.format');
    my $preset = $main::config->param('presets.preset');

    my $output_file_name = undef;
    if ($main::config->param('name.continue') == 1) {
        # continue filename based on existing files
        my $dh = new FileHandle;
        if (!opendir($dh, ".")) {
            print STDERR "Cannot open current directory\n";
            print STDERR "Error: $!\n";
            exit(1);
        }
        my $highest_existing_file_number = 0;
        while (my $entry = readdir($dh)) {
            if ($entry eq '.' or $entry eq '..') {
                next;
            }
            if ($entry =~ /^$name(\d+)\.$format$/) {
                my $file_number = $1;
                #print "found matching file: $entry\n";
                if ($file_number > $highest_existing_file_number) {
                    $highest_existing_file_number = $file_number;
                }
            }
        }
        closedir($dh);
        $output_file_name = $name . sprintf("%02u", $highest_existing_file_number + 1) . '.' . $format;
    } else {
        # define a full filename
        $output_file_name = $name . '.' . $format;
        if (-f $output_file_name) {
            print STDERR "Output file already exist: $output_file_name\n";
            exit(1);
        }
    }
    print "File name: $output_file_name\n";

    my @written_audio = ();
    my @requested_audio = $main::config->param('audio.languages');
    foreach my $requested_audio (@requested_audio) {
        foreach my $audio_nr (sort(keys(%{$result->{'titles'}->{$title_nr}{'audio'}}))) {
            #print "audio: $audio_nr (" . $result->{'titles'}->{$title_nr}{'audio'}->{$audio_nr}{'3cc'} . ")\n";
            if ($result->{'titles'}->{$title_nr}{'audio'}->{$audio_nr}{'3cc'} eq $requested_audio) {
                push(@written_audio, $audio_nr);
            }
        }
    }
    my $written_audio = join(',', @written_audio);
    #print "written audio: $written_audio\n";

    my @written_subtitle = ();
    my @requested_subtitle = $main::config->param('subtitle.languages');
    foreach my $requested_subtitle (@requested_subtitle) {
        foreach my $subtitle_nr (sort(keys(%{$result->{'titles'}->{$title_nr}{'subtitle'}}))) {
            #print "subtitle: $subtitle_nr (" . $result->{'titles'}->{$title_nr}{'subtitle'}->{$subtitle_nr}{'3cc'} . ")\n";
            if ($result->{'titles'}->{$title_nr}{'subtitle'}->{$subtitle_nr}{'3cc'} eq $requested_subtitle) {
                push(@written_subtitle, $subtitle_nr);
            }
        }
    }
    my $written_subtitle = join(',', @written_subtitle);
    #print "written subtitle: $written_subtitle\n";

    my $start_time = time();
    if ($main::config->param('time.display') == 1) {
        print "Time: " . human_timestamp() . "\n";
    }
    $main::handbrake->encode($title_nr, $output_file_name, $format, $written_audio, $written_subtitle, $preset);
    my $end_time = time();
    print "Time for encoding: " . formatted_time($end_time - $start_time) . "\n";
    if (-f $output_file_name) {
        my @stat = stat($output_file_name);
        print "File size: " . formatted_size($stat[7]) . "\n";
    } else {
        print STDERR "Encoding failed!\n";
    }
}

print "Finished $this_number titles\n";

# eject the disk
if ($main::config->param('device.eject') == 1) {
    system($main::eject . ' ' . $main::config->param('device.name'));
}

exit(0);





# help()
#
# output help
#
# parameter:
#  none
# return:
#  none
sub help {
    print "\n";
    print "Encode DVD\n";
    print "\n";
    print "Usage: $0 <options>...\n";
    print "\n";
    print "Options:\n\n";
    print " -h --help       display this help\n";
    print "    --debug      display debugging information (not available)\n";
    print " -d --device     specify DVD device\n";
    print "    --min-time   specify minimum time for a track\n";
    print "    --max-time   specify maximum time for a track\n";
    print "    --name       specify output name, without format\n";
    print " -c --continue   specify if the DVD is part of a collection and the\n";
    print "                 script should attach and increase a double-digit number\n";
    print "                 to each title, existing files with the same pattern\n";
    print "                 are considered\n";
    print "    --format     format of the output file (m4v, mkv)\n";
    print "    --audio      comma-separated list of 3-char language codes where the\n";
    print "                 audio track is to include in the output file\n";
    print "    --subtitle   comma-separated list of 3-char language codes where the\n";
    print "                 subtitle is to include in the output file\n";
    print " -e --eject      eject the disk after job is done\n";
    print "    --eject-path path to eject program\n";
    print " -t --time       display the time when encoding started\n";
    print "    --preset     HandBrake preset\n";
    print "                 defaults to: Normal\n";
    print "\n\n";
    print "If ~/.handbrake-encode.conf exists it will be parsed before applying\n";
    print "commandline options\n";
    print "\n";
}


# human_readable_time()
#
# format seconds into hours, minutes and seconds
#
# parameter:
#  - time
# return:
#  - formatted time
sub human_readable_time {
    my $time = shift;

    my $return = '';
    if ($time > 3600) {
        my $tmp = int($time / 3600);
        $return .= $tmp . 'h';
        $time = $time - $tmp * 3600;
    }
    if ($time > 60) {
        my $tmp = int($time / 60);
        $return .= $tmp . 'm';
        $time = $time - $tmp * 60;
    } elsif (length($return) > 0) {
        $return .= '0m';
    }
    $return .= $time . 's';

    return $return;
}


# formatted_time()
#
# return a formatted timestamp
#
# parameter:
#  - time in seconds
# return:
#  - string with formatted timestamp
sub formatted_time {
  my $time = shift;

  if ($time < 0) {
    return $time;
  }
  if ($time == 0) {
    return '0s';
  }

  my $return = '';

  my $days = 0;
  my $hours = 0;
  my $minutes = 0;
  my $seconds = 0;

  if ($time > 86400) {
    $days = floor($time / 86400);
    $time = $time - $days * 86400;
  }

  if ($time > 3600) {
    $hours = floor($time / 3600);
    $time = $time - $hours * 3600;
  }

  if ($time > 60) {
    $minutes = floor($time / 60);
    $time = $time - $minutes * 60;
  }

  $seconds = $time;


  if ($days > 0) {
    $return .= $days . 'd';
  }
  if ($hours > 0 or $days > 0) {
    $return .= $hours . 'h';
  }
  if ($minutes > 0 or $days > 0 or $hours > 0) {
    $return .= $minutes . 'm';
  }
  if ($seconds > 0 or $days > 0 or $hours > 0 or $minutes > 0) {
    $return .= $seconds . 's';
  }

  return $return;
}


# formatted_size()
#
# return a formatted size
#
# parameter:
#  - size in bytes
# return:
#  - string with formatted size
sub formatted_size {
  my $size = shift;

  if ($size < 0) {
    return $size . 'B';
  }
  if ($size == 0) {
    return '0B';
  }

  my $return = '';

  my $tbytes = 0;
  my $gbytes = 0;
  my $mbytes = 0;
  my $kbytes = 0;
  my $bytes = 0;

  if ($size > (1024 * 1024 * 1024 * 1024)) {
    $tbytes = floor($size / (1024 * 1024 * 1024 * 1024));
    $size = $size - $tbytes * (1024 * 1024 * 1024 * 1024);
  }

  if ($size > (1024 * 1024 * 1024)) {
    $gbytes = floor($size / (1024 * 1024 * 1024));
    $size = $size - $gbytes * (1024 * 1024 * 1024);
  }

  if ($size > (1024 * 1024)) {
    $mbytes = floor($size / (1024 * 1024));
    $size = $size - $mbytes * (1024 * 1024);
  }

  if ($size > 1024) {
    $kbytes = floor($size / 1024);
    $size = $size - $kbytes * 1024;
  }
  $bytes = $size;
  #print "$tbytes, $gbytes, $mbytes, $kbytes, $bytes\n";

  if ($tbytes > 0) {
    $return = $tbytes;
    if ($mbytes > 0) {
      $gbytes = $gbytes / 1000;
      $gbytes =~ s/^\d*\.//;
      $return .= '.' . $gbytes;
      $return = floor($return * 100) / 100;
    }
    $return .= ' TB';
  } elsif ($gbytes > 0) {
    $return = $gbytes;
    if ($mbytes > 0) {
      $mbytes = $mbytes / 1000;
      $mbytes =~ s/^\d*\.//;
      $return .= '.' . $mbytes;
      $return = floor($return * 100) / 100;
    }
    $return .= ' GB';
  } elsif ($mbytes > 0) {
    $return = $mbytes;
    if ($kbytes > 0) {
      $kbytes = $kbytes / 1000;
      $kbytes =~ s/^\d*\.//;
      $return .= '.' . $kbytes;
      $return = floor($return * 100) / 100;
    }
    $return .= ' MB';
  } elsif ($kbytes > 0) {
    $return = $kbytes;
    if ($bytes > 0) {
      $bytes = $bytes / 1000;
      $bytes =~ s/^\d*\.//;
      $return .= '.' . $bytes;
      $return = floor($return * 100) / 100;
    }
    $return .= ' kB';
  }

  return $return;
}


# human_timestamp()
#
# return a human readable timestamp from localtime()
#
# parameter:
#  none
# return:
#  - string with timestamp
sub human_timestamp {
  # get actual timestamp
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
  # calculate the tm struct differences
  $mon++;
  $wday++;
  $year = $year + 1900;
  # build and return timestamp
  return sprintf("%02d.%02d.%04d %02d:%02d:%02d", $mday, $mon, $year, $hour, $min, $sec);
}
