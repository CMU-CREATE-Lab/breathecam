#!/usr/bin/env ruby

# Create a time machine from breathecam imagery

require 'fileutils'
require 'date'
require 'time'
require 'json'
require 'parallel'
require 'active_support'
require 'active_support/core_ext'

$CURRENT_SCRIPT_PATH = File.expand_path(File.dirname(__FILE__))
$RUNNING_WINDOWS = /(win|w)32$/.match(RUBY_PLATFORM)
$RUNNING_MAC = RUBY_PLATFORM.downcase.include?("darwin")
$RUNNING_LINUX = RUBY_PLATFORM.downcase.include?("linux")

# For lossless image rotations
$jpegtran_path = $RUNNING_WINDOWS ? "jpegtran.exe" : "jpegtran"

# Hugin tools
$nona_path = $RUNNING_WINDOWS ? "nona.exe" : "nona"
$enblend_path = $RUNNING_WINDOWS ? "enblend.exe" : "enblend"
$multiblend_path = $RUNNING_WINDOWS ? "multiblend.exe" : "multiblend"

# Imagemagick
$imagemagick_path = $RUNNING_WINDOWS ? "convert.exe" : "convert"

# ffmpeg
$ffmpeg_path = $RUNNING_WINDOWS ? "ffmpeg.exe" : "ffmpeg"

# qtfaststart
$qtfaststart_path = $RUNNING_WINDOWS ? "qtfaststart.exe" : "qtfaststart"

# Masking
$masker_path = "#{$CURRENT_SCRIPT_PATH}/MaskedGaussian/MaskedGaussian"

# Image diffing (mse)
$image_diff_path = "#{$CURRENT_SCRIPT_PATH}/image-diff.py"

# Concatnenate mp4s
# As of 03/2024, Concatenate-mp4-videos.py still requires python2
$mp4_concat_path = "python2 #{$CURRENT_SCRIPT_PATH}/libs/mp4-concatenate/Concatenate-mp4-videos.py"

# Rsync script
$rsync_script = "#{$CURRENT_SCRIPT_PATH}/breathecam_rsync_and_delete_source_images.rb"

$valid_image_extensions = [".jpg", ".JPG", ".jpeg", ".JPEG", ".png", ".PNG", ".lnk"]
$default_num_jobs = 4
$rsync_input = false
$rsync_location_json = false
$skip_stitch = false
$skip_leader = false
$skip_trailer = false
$input_date_from_file = false
$camera_type = "breathecam"
$skip_qtfaststart_append = false
$skip_videos = false
$apply_mask = false
$symlink_input = false
$sort_by_exif_dates = false
$start_time = {}
$end_time = {}
$append_inplace = false
$future_appending_frames = 17000
$num_time_chunks_checked = 0
$is_monthly = false
$skip_img_validation = false
$repair_img = false
$num_images_to_stitch = 4
$stitcher = "hugin"
# Default to epoch time
$file_names_date_format = "%s"
$force_trim_on_working_dir = false
$use_multiblend_for_hugin = false
$calculate_image_mse = false
$mse_golden_images = []
$use_faster_file_lookup = false
# What percent of expected frames do we accept not being processed?
# This is relevant to the automated rsyncing/deleting of source images.
$percent_accepted_frame_loss = 0.05
$root_tile_url = ""

if $RUNNING_WINDOWS
  require File.join(File.dirname(__FILE__), 'shortcut')
end

class Compiler
  def initialize(args)

    if args.length < 1
      usage
    end

    puts "Start Time: #{Time.now}"

    $definition_file_path = ARGV[0]

    while !ARGV.empty?
      arg = ARGV.shift
      if arg == "-input-path"
        $input_path = ARGV.shift
      elsif arg == "-output-path"
        $output_path = ARGV.shift
      elsif arg == "-j"
        $num_jobs = ARGV.shift.to_i
      elsif arg == "--rsync-input"
        $rsync_input = true
      elsif arg == "--rsync-location-json"
        $rsync_location_json = true
      elsif arg == "-current-day"
        $current_day = ARGV.shift
      elsif arg == "-incremental-update-interval"
        # In minutes
        $incremental_update_interval = ARGV.shift.to_i
      elsif arg == "-rotate-by-list"
        # If a multi-cam, pass in a list corresponding to the desired image rotation amount for
        # each cam. If no rotation is required for a particular camera of a multi-cam, pass in a 0
        # for the corresponding index. If not a multi-cam, just pass one value.
        $rotate_by_list = ARGV.shift.split(",")
      elsif arg == "-alter-gamma-amount"
        $alter_gamma_amount = ARGV.shift.to_f
      elsif arg == "-crop-amount-bounds"
        # Format is L,B,R,T (left, bottom, right, top)
        $crop_amount_bounds = ARGV.shift.split(",")
      elsif arg == "-resize-dimensions-percentage"
        # Format is WxH, where values above 100 enlarge the dimension and values below 100 shrink it.
        # Aspect ratio is ignored.
        $resize_dimensions_percentage = ARGV.shift.split(",")
      elsif arg == "--force-trim-on-working-dir"
        $force_trim_on_working_dir = true
      elsif arg == "-working-dir"
        $working_dir = ARGV.shift
      elsif arg == "--skip-stitch"
        $skip_stitch = true
      elsif arg == "--skip-leader"
        $skip_leader = true
      elsif arg == "--skip-trailer"
        $skip_trailer = true
      elsif arg == "--input-date-from-file"
        $input_date_from_file = true
      elsif arg == "-camera-type"
        $camera_type = ARGV.shift
      elsif arg == "--skip-qtfaststart-append"
        $skip_qtfaststart_append = true
      elsif arg == "--skip-videos"
        $skip_videos = true
      elsif arg == "--apply-mask"
        $apply_mask = true
      elsif arg == "-img-mask-inpaint"
        $img_mask_inpaint_path = ARGV.shift
      elsif arg == "-img-mask-gaus"
        $img_mask_gaus_path = ARGV.shift
      elsif arg == "-subsample-input"
        $subsample_input = ARGV.shift.to_i
      elsif arg == "--symlink-input"
        $symlink_input = true
      elsif arg == "--sort-by-exif-dates"
        $sort_by_exif_dates = true
      elsif arg == "--append-inplace"
        $append_inplace = true
      elsif arg == "-future-appending-frames"
        $future_appending_frames = ARGV.shift.to_i
      elsif arg == "--image-store-v2"
        $image_store_v2 = true
      elsif arg == "--file-names-include-dates"
        $file_names_include_dates = true
      elsif arg == "-file-names-date-format"
        $file_names_date_format = ARGV.shift
      elsif arg == "--is-monthly"
        $is_monthly = true
      elsif arg == "--skip-img-validation"
        $skip_img_validation = true
      elsif arg == "-camera-list"
        $camera_list = ARGV.shift.to_s.split(",")
      elsif arg == "-stitcher"
        $stitcher = ARGV.shift
      elsif arg == "--create-top-video-only"
        $create_top_video_only = true
      elsif arg == "-image-capture-interval"
        # In seconds
        $image_capture_interval = ARGV.shift.to_i
      elsif arg == "-stitcher-master-alignment-file"
        $stitcher_master_alignment_file = ARGV.shift.to_s
      elsif arg == "--use-multiblend-for-hugin"
        $use_multiblend_for_hugin = true
      elsif arg == "-video-tile-mode"
        $video_tile_mode = ARGV.shift
      elsif arg == "-ramdisk-path"
        $ramdisk_path = ARGV.shift
      elsif arg == "-percent-accepted-frame-loss"
        $percent_accepted_frame_loss = ARGV.shift
      elsif arg == "--repair-img"
        $repair_img = true
      end
    end

    # Process definition file, which has taken the place of all the arguments previously passed in above.
    $definition_file = load_definition_file()
    $camera_location = $definition_file["id"]
    $time_zone = $definition_file["source"]["time_zone"]
    # Set global variables, based on key name from the definition file, to the values set in the definition file
    $definition_file['config'].each do |key, val|
      val = "'#{val}'" if val.is_a?(String)
      eval("$#{key} = #{val}")
    end

    $num_images_to_stitch = ($camera_list.length <= 1 ? 0 : $camera_list.length) if $camera_list

    if !$rsync_input && !$camera_list && !File.exists?(File.expand_path($input_path))
      puts "Invalid input path: #{$input_path}"
      exit
    end

    if !$rsync_output_info && $output_path && !File.exists?(File.expand_path($output_path))
      puts "Invalid output path: #{$output}"
      exit
    end

    if $rsync_output_info && $rsync_output_info['host'] && $rsync_output_info['dest_root']
      $output_path = "#{$rsync_output_info['host']}:#{$rsync_output_info['dest_root']}/#{$camera_location}"
    end

    # Specify where all 0XXX directories go. If the user does not pass in a custom path, then default to main output directory
    unless $working_dir
      if $rsync_output_info || $rsync_location_json
        $working_dir = File.join(File.dirname(__FILE__), "#{$camera_location}.tmc")
      else
        $working_dir = File.join($output_path, "#{$camera_location}.tmc")
      end
    end

    $timemachine_output_path = $rsync_output_info || $rsync_location_json ? $working_dir : $output_path

    # If the user specifies a chunk of time to process or we are reading a start time from a file (which we treat as a chunk of time, as opposed to a full day, though it may be that), set to true.
    $do_incremental_update = true if defined?($incremental_update_interval) or $input_date_from_file

    if $current_day && $do_incremental_update
      puts "Specifying a day AND doing incremental appending is not supported. You can only do incremental appending from the actual day of running the script. \n So, either just specify a day OR specify incremental updating."
      exit
    end

    if File.exists?(File.join($working_dir, "WIP"))
      puts "[#{Time.now}] A file called 'WIP' was detected in '#{$working_dir}', which indicates that this working directory is already in the middle of processing. Exiting new process."
      exit
    end

    puts "Starting process."

    at_exit do
      puts "Process exited."
      FileUtils.rm(File.join($working_dir, "WIP"))
    end

    FileUtils.mkdir_p($working_dir)
    FileUtils.touch(File.join($working_dir, "WIP"))
    #create_definition_file
    create_ramdisk_links() if $ramdisk_path

    # Set time zone based on definition file
    Time.zone = $time_zone || "Eastern Time (US & Canada)"
    # Current time of running the script
    $current_time_of_run = Time.zone.now
    # Default to 10 minutes if no update chunk interval given
    $incremental_update_interval ||= 10
    # Number of processess to run in parallel
    $num_jobs ||= $default_num_jobs

    calculate_rsync_input_range
    clear_working_dir
    $rsync_input || $symlink_input ? get_source_images : $skip_stitch ? create_tm : organize_images
  end

  def load_definition_file
    if File.exists?($definition_file_path)
      return open($definition_file_path) {|fh| JSON.load(fh)}
    else
       puts "Error opening definition file: '#{$definition_file_path}'. Does this file exist? Exiting process."
       exit
    end
  end

  #def create_definition_file
  #  path_to_definition_file = "#{$working_dir}/definition.tmc"
  #  if File.exists?(path_to_definition_file)
  #    json = open(path_to_definition_file) {|fh| JSON.load(fh)}
  #    $time_zone = json["source"]["time_zone"]
  #  else
  #    FileUtils.cp("#{File.dirname(__FILE__)}/default_definition.tmc", path_to_definition_file)
  #    json = open(path_to_definition_file) {|fh| JSON.load(fh)}
  #    location_name = camera_name_remap($camera_location)
  #    json["id"] = location_name
  #    json["label"] = location_name
  #    json["split_type"] = $is_monthly ? "monthly" : "daily"
  #    # Use default time parser unless we are using a breathecam specific camera
  #    json["source"].delete("capture_time_parser") unless $camera_type == "breathecam"
  #    open(path_to_definition_file, "w") {|fh| fh.puts(JSON.pretty_generate(json))}
  #  end
  #end

  def camera_name_remap(camera_location)
    if (camera_location == "heinz")
      return "north_shore"
    elsif (camera_location == "trimont1")
      return "downtown"
    elsif (camera_location == "walnuttowers1")
      return "mon_valley"
    elsif (camera_location == "pitt1")
      return "oakland"
    else
      return camera_location
    end
  end

  def calculate_rsync_input_range
    time_chunk_in_seconds = 60 * $incremental_update_interval

    if $input_date_from_file
      file = File.join($working_dir, "#{$camera_location}-last-pull-date.txt")
      if File.exists?(file)
        $last_pull_time = Time.zone.parse(File.open(file, &:readline)) + (time_chunk_in_seconds * $num_time_chunks_checked)
        if !$initial_last_pull_time
          $initial_last_pull_time = $last_pull_time
        end
        # We may be running this script once a minute so make sure we only process a specified chunk of time
        time_diff = ($current_time_of_run - $last_pull_time).floor
        if time_diff < time_chunk_in_seconds
          puts "[#{Time.now}] Gap less than #{$incremental_update_interval} minutes, which is less than the minimum segment. Exiting process."
          exit
        end
        # Current day is now based on the day in the last pull file
        $current_day = $last_pull_time.to_date.to_s
        if !$initial_current_day
          $initial_current_day = $current_day
        end
        tmp_start_time = $last_pull_time
        tmp_end_time = $last_pull_time + time_chunk_in_seconds
      else
        # Current day is now the day of running the script
        $current_day = $current_time_of_run.to_date.to_s
        tmp_start_time = $current_time_of_run - time_chunk_in_seconds
        tmp_end_time = $current_time_of_run
      end
    elsif $current_day
      # Process a full day, based on a date string passed in
      current_time_obj = Time.zone.parse($current_day)
      tmp_start_time = current_time_obj.beginning_of_day
      tmp_end_time = current_time_obj.end_of_day
    else
      # Process part of the current day based on a chunk of time in minutes in the past from the current time of running the script
      $current_day = $current_time_of_run.to_date.to_s
      tmp_start_time = $current_time_of_run - time_chunk_in_seconds
      tmp_end_time = $current_time_of_run
    end

    # $current_day may have changed from above
    current_time_obj = Time.zone.parse($current_day)

    # Ensure start time is of the same day
    tmp_start_time = current_time_obj.beginning_of_day if tmp_start_time.to_date.to_s < $current_day.to_s
    # If end time goes past the current day, wrap around to start of next day from the what is presently set as $current_day
    if tmp_end_time.to_date.to_s > $current_day.to_s
      # 1 day in seconds
      current_time_obj += 86400
      tmp_end_time = current_time_obj.beginning_of_day
    end
    # Make sure we don't go past the current time of running, since images don't exist past that point
    tmp_end_time = $current_time_of_run if tmp_end_time > $current_time_of_run

    $start_time["hour"] = tmp_start_time.strftime("%H").to_i
    $start_time["minute"] = tmp_start_time.strftime("%M").to_i
    $start_time["sec"] = tmp_start_time.strftime("%S").to_i
    # Offsets need to be prepended by + or -
    start_time_zone_offset = (tmp_start_time.utc_offset / 3600) * 100
    if start_time_zone_offset > 0
      start_time_zone_offset = "+" + start_time_zone_offset.to_s
    end
    $start_time["full"] = "#{tmp_start_time.to_date} #{'%02d' % $start_time['hour']}:#{'%02d' % $start_time['minute']}:#{'%02d' % $start_time['sec']} #{start_time_zone_offset}"

    $end_time["hour"] = tmp_end_time.strftime("%H").to_i
    $end_time["minute"] = tmp_end_time.strftime("%M").to_i
    $end_time["sec"] = tmp_end_time.strftime("%S").to_i
    end_time_zone_offset = (tmp_end_time.utc_offset / 3600) * 100
    # Offsets need to be prepended by + or -
    if end_time_zone_offset > 0
      end_time_zone_offset = "+" + end_time_zone_offset.to_s
    end
    $end_time["full"] = "#{tmp_end_time.to_date} #{'%02d' % $end_time['hour']}:#{'%02d' % $end_time['minute']}:#{'%02d' % $end_time['sec']} #{end_time_zone_offset}"
  end

  def file_dir_or_symlink_exists?(path_to_file)
    File.exist?(path_to_file) || File.symlink?(path_to_file)
  end

  def create_ramdisk_links
    system("mkdir -p #{$ramdisk_path}/#{$camera_location}.tmc/0200-tiles")
    system("ln -s #{$ramdisk_path}/#{$camera_location}.tmc/0200-tiles #{$working_dir}/") unless file_dir_or_symlink_exists?("#{$working_dir}/0200-tiles")
    system("mkdir -p #{$ramdisk_path}/#{$camera_location}.tmc/0300-tilestacks")
    system("ln -s #{$ramdisk_path}/#{$camera_location}.tmc/0300-tilestacks #{$working_dir}/") unless file_dir_or_symlink_exists?("#{$working_dir}/0300-tilestacks")
  end

  def clear_working_dir
    puts "[#{Time.now}] Removing previous working files..."
    # Delete the contents of the directories, not the directories themselves since they may be symlinked.
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/050-raw-images/*"))
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/075-organized-raw-images/*"))
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0100-original-images/*"))
    FileUtils.rm_rf("#{$working_dir}/0100-unstitched")
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0200-tiles/*"))
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0300-tilestacks/*"))
    FileUtils.rm_rf(Dir.glob("#{$timemachine_output_path}/*-*m.timemachine"))
    video_sets = Dir.glob("#{$timemachine_output_path}/*.timemachine").sort
    check_date = $is_monthly ? Date.parse($current_day).beginning_of_month.to_s : $current_day
    $create_videoset_segment_directory = false
    if $do_incremental_update and !video_sets.empty? and video_sets.any?{|s| s.include?(check_date)}
      $create_videoset_segment_directory = true
    end
    puts "[#{Time.now}] Finished removing old files."
  end

  def get_source_images
    $camera_paths = $camera_list ? $camera_list : [$input_path]
    tmp_input_path = ""
    $camera_paths.each_with_index do |camera_path, idx|
      puts "[#{Time.now}] Getting source images from #{camera_path}/#{$current_day}"
      image_path = $skip_stitch ? "0100-original-images" : "050-raw-images"
      new_input_path = File.join($working_dir, image_path, idx.to_s)
      FileUtils.mkdir_p(new_input_path)
      args = camera_path.split(":")
      host = args[0]
      # Root camera image path
      src_path = args[1] || args[0]
      # Camera date path
      img_folder = "/#{$current_day}"
      if $image_store_v2
        year_month_day = $current_day.split("-")
        # YYYY/MM
        img_folder = $is_monthly ? File.join(year_month_day[0], year_month_day[1]) : File.join(year_month_day[0], year_month_day[1], $current_day)
      end
      if $file_names_include_dates
        start_date_formatted = Time.zone.parse($start_time['full']).utc.strftime($file_names_date_format)
        end_date_formatted = Time.zone.parse($end_time['full']).utc.strftime($file_names_date_format)
        logic_operator1 = $start_time["hour"].to_i + $start_time["minute"].to_i + $start_time["sec"].to_i == 0 ? ">=" : ">"
        logic_operator2 = $start_time["hour"].to_i + $start_time["minute"].to_i + $start_time["sec"].to_i == 0 ? "<" : "<="
        if $use_faster_file_lookup
          if logic_operator1 == ">"
            start_date_formatted = start_date_formatted.to_i + 1
          end
          if logic_operator2 == "<"
            end_date_formatted = end_date_formatted.to_i - 1
          end
          # Much faster than the find/perl combo, but does hit the 'argument list too long' limit
          file_list_command = "bash -c \"ls #{src_path}/#{img_folder}/{#{start_date_formatted}..#{end_date_formatted}}{#{$valid_image_extensions.join(',')}} 2>/dev/null | sed 's#.*/##'\""
        else
          file_list_command = "find #{src_path}/#{img_folder}/ -maxdepth 1 -type f -printf '%f\n' | perl -ne 'print if (m!(\\d+)*.[jJpP][pPnN][gG]! and $1 #{logic_operator1} #{start_date_formatted} and $1 #{logic_operator2} #{end_date_formatted})'"
        end
      else
        file_list_command = "bash -O extglob -c \"find #{src_path}/#{img_folder}/*.[jJpP][pPnN]*(e)*(E)[gG] -maxdepth 1 -type f -newermt '#{$current_day} #{'%02d' % $start_time['hour']}:#{'%02d' % $start_time['minute']}:00' ! -newermt '#{$current_day} #{'%02d' % $end_time['hour']}:#{'%02d' % $end_time['minute']}:#{'%02d' % $end_time['sec']}' -printf '%f\n'\""
      end
      subsample_command = $subsample_input ? "| sed -n '1~#{$subsample_input}p'" : ""
      puts "[#{Time.now}] #{file_list_command} #{subsample_command}"
      if $symlink_input
        puts "[#{Time.now}] Symlinking source images."
        if $do_incremental_update or $subsample_input
          file_list = `#{file_list_command} #{subsample_command}`
          file_list = file_list.split("\n")
          file_list.each do |file|
            system("ln -s #{src_path}/#{img_folder}/#{file} #{new_input_path}/#{File.basename(file)}")
          end
        else
          system("ln -s #{src_path}/#{img_folder}/* #{new_input_path}")
        end
      else
        puts "[#{Time.now}] Rsyncing source images."
        if $do_incremental_update or $subsample_input
          # Writing to a file to prevent extensive quoting and commandline escaping madness
          commands_to_run = "#{file_list_command} #{subsample_command} > /tmp/#{$camera_location}-files.txt"
          rsync_input_prefix = ""
          # If host is a mounted fileshare (e.g. NFS), don't do remote command
          if not host.match(/^\//).nil?
            system(commands_to_run)
          else
            # Need to escape $ or it will be expanded by echo below
            # Also need to escape any double quotes since echo will be calling this command string
            commands_to_run = commands_to_run.gsub("$","\\$").gsub('"','\"')
            commands_file = "/tmp/#{$camera_location}-ssh.sh"
            system("echo \"#{commands_to_run}\" > #{commands_file}")
            system("cat #{commands_file} | ssh -T #{host} > /dev/null")
            rsync_input_prefix = ":"
          end
          # Cannot get files-from to use absolute paths (hence the need for -printf in the file_list_command) with remote transfers...Clearly missing something important in how this works.
          system("rsync -a --files-from=#{rsync_input_prefix}/tmp/#{$camera_location}-files.txt #{camera_path}/#{$current_day}/ #{new_input_path}/")
        else
          system("bash -c \"rsync -av --include='*.'{#{$valid_image_extensions.join(',')}} --exclude='*' #{camera_path}/#{$current_day}/ #{new_input_path}/\"")
        end
      end
      tmp_input_path = $camera_list ? File.dirname(new_input_path) : new_input_path
    end
    repair_img_extraneous_bytes_error(tmp_input_path) unless $RUNNING_WINDOWS or !$repair_img
    remove_corrupted_images(tmp_input_path) unless $RUNNING_WINDOWS or $skip_img_validation

    # Check if we have enough images to do anything
    dir = Dir.glob("#{tmp_input_path}/**/*{#{$valid_image_extensions.join(',')}}")
    if dir.length <= 2
      puts "<= 2 images found. Because of the current inability to append <= 2 frames with the inline method, we skip processing for this time chunk."
      if $input_date_from_file
        # Keep looking for images up to the current time
        if Time.zone.parse($end_time["full"]).to_i < $current_time_of_run.to_i
          $num_time_chunks_checked += 1
          calculate_rsync_input_range()
          clear_working_dir
          get_source_images
        end
      end
      exit
    end

    # We need to reference files locally (though it may be a symlink) now that we have a valid path to images that are ready to be processed
    $input_path = tmp_input_path
    FileUtils.touch(File.join($input_path, "DONE"))

    # Update the date file with the last time we were able to process
    if $input_date_from_file
      file = File.join($working_dir, "#{$camera_location}-last-pull-date.txt")
      tmp_file = file + ".tmp"
      File.open(tmp_file, 'w') {|f| f.write($end_time["full"])}
      File.rename(tmp_file, file)
    end

    puts "[#{Time.now}] Finished getting source images."

    # We have a directory of images ready to turn into videos.
    if $skip_stitch
      crop_images if $crop_amount_bounds
      alter_image_gamma if $alter_gamma_amount
      rotate_images if $rotate_by_list
      resize_images if $resize_dimensions_percentage
      create_tm
    else
      # We need to match/organize images for stitching. Video creation comes after that.
      $camera_list ? match_images : organize_images
    end
  end

  def repair_img_extraneous_bytes_error(path_to_check)
    puts "[#{Time.now}] Running 'mogrify' on images to re-encode and fix typical 'extraneous bytes' error."
    cam_dirs = Dir.glob("#{path_to_check}/*/")
    Parallel.each(cam_dirs, :in_threads => [cam_dirs.length, $num_jobs].min) do |cam_dir|
      puts "[#{Time.now}] Attempting to repair images in #{cam_dir}"
      system("find #{cam_dir} -maxdepth 3 -name '*.[jJ][pP][gG]' | xargs mogrify -quiet 2>/dev/null")
    end
  end

  def remove_corrupted_images(path_to_check)
    puts "[#{Time.now}] Starting check for corrupted images."
    cam_dirs = Dir.glob("#{path_to_check}/*/")
    Parallel.each(cam_dirs, :in_threads => [cam_dirs.length, $num_jobs].min) do |cam_dir|
      puts "[#{Time.now}] Checking #{cam_dir} for corrupted images."
      # Check for empty files and remove them, which is all we can do for pngs at this time
      system("find -L #{cam_dir} -maxdepth 3 -name '*.[pP][nN][gG]' -empty -print0 | xargs -0 -r rm")
      # Find all jpg files and remove them if they are deemed corrupted (empty, bad headers, etc)
      system("find #{cam_dir} -maxdepth 3 -name '*.[jJ][pP][gG]' | xargs jpeginfo -cd")
    end
  end

  def match_images
    # TODO: Assumes images are of the format EPOCHDATE.([jJ][pP][gG]|lnk)
    $organized_images_path = File.join($working_dir, "075-organized-raw-images")
    count = 0
    match_count = 0
    puts "[#{Time.now}] Matching images..."

    camera_dirs = Dir.glob("#{$input_path}/*").select { |file| File.directory? file }.sort
    parent_path = camera_dirs.first

    images = Dir.glob("#{parent_path}/*{#{$valid_image_extensions.join(',')}}").sort
    # We should already have some images by this point but we check again just incase
    if images.length == 0
      puts "No images found to be processed. Aborting."
      exit
    end
    images.each do |img|
      count += 1
      camera_match_count = 0
      file_name = File.basename(img)
      file_extension = File.extname(img)
      date = File.basename(img, ".*")

      camera_dirs.reject {|camera_dir| camera_dir == parent_path}.each do |camera_dir|
        camera_match_count += 1 if File.exists?(File.join(camera_dir, file_name))
      end

      # Image is missing from the other cameras. We cannot process this set.
      # TODO: Maybe have a threshold in the event times are slightly off, but really the cameras should be taking at exactly the same time.
      next if camera_match_count != camera_dirs.length - 1

      dir = "#{$organized_images_path}/#{'%05d' % count}"
      FileUtils.mkdir_p(dir)
      unless File.exists? File.expand_path(dir)
        puts "Failed to create output directory. Please check read/write permissions on the output directory."
        return
      end
      # Note: Windows Vista+ does support something that is essentially a symlink, but for now we will just stick with shortcuts that have worked with all versions of Windows up to Windows 7. Probably Windows 8 too but have not tested there.
      if $RUNNING_WINDOWS
        # No support at this time
      else
        camera_dirs.each_with_index do |camera_dir, i|
          File.symlink(File.expand_path("#{camera_dir}/#{date}#{file_extension}"), "#{dir}/#{date}_image#{i+1}#{file_extension}")
        end
      end
      match_count += 1
    end
    puts "[#{Time.now}] Organizing complete. Matched #{match_count} out of #{count} possible frames."
    if match_count <= 2
      puts "<= 2 images found. Because of the current inability to append <= 2 frames with the inline method, we skip processing and check again later when more images are available."
      exit
    end
    rotate_images if $rotate_by_list
    resize_images if $resize_dimensions_percentage
    stitch_images
  end

  # OLD; Deprecated (Arecont camera days)
  def organize_images
    # TODO: Assumes images are of the format EPOCHDATE_image{1,2,3,4}.([jJ][pP][gG]|lnk)
    $organized_images_path = File.join($working_dir, "075-organized-raw-images")
    count = 0
    match_count = 0
    puts "[#{Time.now}] Organizing images..."
    images = Dir.glob("#{$input_path}/*_image1{#{$valid_image_extensions.join(',')}}").sort
    # We should already have some images by this point but we check again just incase
    if images.length == 0
      puts "No images found to be processed. Aborting."
      exit
    end
    images.each do |img|
      count += 1
      file_extension = File.extname(img)
      date = File.basename(img, ".*").split("_")[0]
      unless File.exists?("#{$input_path}/#{date}_image2#{file_extension}") && File.exists?("#{$input_path}/#{date}_image3#{file_extension}") && File.exists?("#{$input_path}/#{date}_image4#{file_extension}")
        puts "Skipping #{date} since images were missing for it."
        next
      end
      path = File.expand_path(File.dirname(img))
      dir = "#{$organized_images_path}/#{'%05d' % count}"
      FileUtils.mkdir_p(dir)
      unless File.exists? File.expand_path(dir)
        puts "Failed to create output directory. Please check read/write permissions on the output directory."
        return
      end
      # Note: Windows Vista+ does support something that is essentially a symlink, but for now we will just stick with shortcuts that have worked with all versions of Windows up to Windows 7. Probably Windows 8 too but have not tested there.
      if $RUNNING_WINDOWS
        for i in 1..4
          Win32::Shortcut.new("#{dir}/#{date}_image#{i}" + ".lnk") do |s|
            # Windows only supports absolute shortcut paths, in order to get them to be relative we need a special program: http://www.csparks.com/Relative/index.html
            s.path = "#{path}/#{date}_image#{i}#{file_extension}"
            s.show_cmd = Win32::Shortcut::SHOWNORMAL
            s.working_directory = Dir.getwd
          end
        end
      else
        for i in 1..4
          File.symlink(File.expand_path("#{path}/#{date}_image#{i}#{file_extension}"), "#{dir}/#{date}_image#{i}#{file_extension}")
        end
      end
      match_count += 1
    end
    puts "[#{Time.now}] Organizing complete. Matched #{match_count} out of #{count} possible frames."
    if match_count <= 2
      puts "<= 2 images found. Because of the current inability to append <= 2 frames with the inline method, we skip processing and check again later when more images are available."
      exit
    end
    rotate_images if $rotate_by_list
    stitch_images
  end

  def crop_images
    count = 0
    match_count = 0
    puts "[#{Time.now}] Croppig images..."
    files = Dir.glob("#{$input_path}/**/*")
    Parallel.each(files, :in_threads => $num_jobs) do |img|
      file_extension = File.extname(img)
      next unless $valid_image_extensions.include? file_extension.downcase
      count += 1
      if $RUNNING_WINDOWS && file_extension == ".lnk"
        img = Win32::Shortcut.open(img).path
        # Get the real file extension now
        file_extension = File.extname(img)
      end
      begin
        # Format of array is LBRT
        if $crop_amount_bounds[0]
          system("#{$imagemagick_path} #{%Q{"#{img}"}} -gravity West -chop #{$crop_amount_bounds[0]}x0 #{%Q{"#{img}"}}")
        end
        if $crop_amount_bounds[1]
          system("#{$imagemagick_path} #{%Q{"#{img}"}} -gravity South -chop 0x#{$crop_amount_bounds[1]} #{%Q{"#{img}"}}")
        end
        if $crop_amount_bounds[2]
          system("#{$imagemagick_path} #{%Q{"#{img}"}} -gravity East -chop #{$crop_amount_bounds[2]}x0 #{%Q{"#{img}"}}")
        end
        if $crop_amount_bounds[3]
          system("#{$imagemagick_path} #{%Q{"#{img}"}} -gravity North -chop 0x#{$crop_amount_bounds[3]} #{%Q{"#{img}"}}")
        end
        match_count += 1
      rescue
        # Ignore and move on
        # TODO: Maybe do something in this case.
      end
    end
    puts "[#{Time.now}] Cropping complete. Cropped #{match_count} out of #{count} images."
  end

  def alter_image_gamma
    count = 0
    match_count = 0
    puts "[#{Time.now}] Altering gamma of images..."
    files = Dir.glob("#{$input_path}/**/*")
    Parallel.each(files, :in_threads => $num_jobs) do |img|
      file_extension = File.extname(img)
      next unless $valid_image_extensions.include? file_extension.downcase
      count += 1
      if $RUNNING_WINDOWS && file_extension == ".lnk"
        img = Win32::Shortcut.open(img).path
        # Get the real file extension now
        file_extension = File.extname(img)
      end
      begin
        # < 1.0 darkens
        # > 1.0 brightens
        system("#{$imagemagick_path} #{%Q{"#{img}"}} -gamma #{$alter_gamma_amount} #{%Q{"#{img}"}}")
        match_count += 1
      rescue
        # Ignore and move on
        # TODO: Maybe do something in this case.
      end
    end
    puts "[#{Time.now}] Gamma altering complete. Altered #{match_count} out of #{count} images."
  end

  def rotate_images
    count = 0
    match_count = 0
    for i in 1..$rotate_by_list.length
      rot_amt = $rotate_by_list[i-1]
      if $rotate_by_list.length == 1
        glob_param = "*.*"
      else
        glob_param = "*_image#{i}.*"
      end
      puts "[#{Time.now}] Rotating images #{rot_amt} degrees clockwise..."
      files = Dir.glob("#{$input_path}/**/{glob_param}").sort
      Parallel.each(files, :in_threads => $num_jobs) do |img|
        file_extension = File.extname(img)
        next unless $valid_image_extensions.include? file_extension.downcase
        count += 1
        if $RUNNING_WINDOWS && file_extension == ".lnk"
          img = Win32::Shortcut.open(img).path
          # Get the real file extension now
          file_extension = File.extname(img)
        end
        begin
          # jpegtran is lossless jpeg rotation
          if file_extension.downcase.include?(".jp")
            system("#{$jpegtran_path} -copy all -rotate #{rot_amt} -optimize -outfile #{%Q{"#{img}"}} #{%Q{"#{img}"}}")
          else
            system("#{$imagemagick_path} #{%Q{"#{img}"}} -rotate #{rot_amt} #{%Q{"#{img}"}}")
          end
          match_count += 1
        rescue
          # Ignore and move on
          # TODO: Maybe do something in this case.
        end
      end
    end
    puts "[#{Time.now}] Rotating complete. Rotated #{match_count} out of #{count} images."
  end

  def resize_images
    count = 0
    match_count = 0
    puts "[#{Time.now}] Resizing images..."
    files = Dir.glob("#{$input_path}/**/*")

    # A value of 100 means keep same dimension size.
    new_width = $resize_dimensions_percentage[0].to_i > 0 ? $resize_dimensions_percentage[0].to_i : 100
    new_height = $resize_dimensions_percentage[1].to_i > 0 ? $resize_dimensions_percentage[1].to_i : 100

    if new_width == 100 and new_height == 100
      puts "[#{Time.now}] No resize dimensions given, skipping."
      return
    end

    Parallel.each(files, :in_threads => $num_jobs) do |img|
      file_extension = File.extname(img)
      next unless $valid_image_extensions.include? file_extension.downcase
      count += 1
      if $RUNNING_WINDOWS && file_extension == ".lnk"
        img = Win32::Shortcut.open(img).path
        # Get the real file extension now
        file_extension = File.extname(img)
      end
      begin
        system("#{$imagemagick_path} #{%Q{"#{img}"}} -resize #{new_width}%!x#{new_height}%! -quiet #{%Q{"#{img}"}}")
        match_count += 1
      rescue
        # Ignore and move on
        # TODO: Maybe do something in this case.
      end
    end
    puts "[#{Time.now}] Resizing complete. Resized #{match_count} out of #{count} images."
  end

  def stitch_images
    count = 0
    match_count = 0
    # Organizing images is done now that we are at this step
    FileUtils.touch(File.join($organized_images_path, "DONE"))
    puts "[#{Time.now}] Stitching images..."
    stitched_images_path = File.join($working_dir, "0100-original-images")
    FileUtils.mkdir_p(stitched_images_path)
    unless File.exists? File.expand_path(stitched_images_path)
      puts "Failed to create output directory for stitched images. Please check read/write permissions on the output directory."
      return
    end
    files = Dir.glob("#{$organized_images_path}/*/*_image1.*").sort
    if ($stitcher == "concatenate")
      # TODO: Only appends horizontally
      Parallel.each(files, :in_threads => $num_jobs) do |img|
        count += 1
        begin
          date = File.basename(img, ".*").split("_")[0]
          parent_path = File.dirname(img)
          file_extension = File.extname(img)
          stitched_image = "#{stitched_images_path}/#{date}_full.jpg"
          concat_input_files_string = ""
          for i in 1..$num_images_to_stitch
            concat_input_files_string += " #{%Q{"#{parent_path}/#{date}_image#{i}#{file_extension}"}}"
          end
          system("#{$imagemagick_path} +append #{concat_input_files_string} #{%Q{"#{stitched_image}"}}")
          match_count += 1
        rescue => e
          puts e
          # Ignore and move on
          # TODO: Maybe do something in this case.
        end
      end
      puts "[#{Time.now}] Concatenating complete. Concatenated #{match_count} out of #{count} possible frames."
      create_tm
    elsif ($stitcher == "gigapan")
      original_images_path = stitched_images_path
      stitched_images_path = File.join($working_dir, "0100-unstitched")
      File.symlink($organized_images_path, stitched_images_path)
      Parallel.each(files, :in_threads => $num_jobs) do |img|
        count += 1
        # Note: Windows Vista+ does support something that is essentially a symlink, but for now we will just stick with shortcuts that have worked with all versions of Windows up to Windows 7. Probably Windows 8 too but have not tested there.
        if $RUNNING_WINDOWS
          # No support at this time
        else
          File.symlink(File.expand_path(img), File.join(original_images_path, File.basename(img)))
        end
      end
      puts "[#{Time.now}] GigaPan Stitcher is about to stitch #{count} frames."
      create_tm
    else
      Dir.chdir($working_dir) do
        Parallel.each(files, :in_threads => $num_jobs) do |img|
          file_extension = File.extname(img)
          next unless $valid_image_extensions.include? file_extension.downcase
          count += 1
          if $RUNNING_WINDOWS && file_extension == ".lnk"
            img = Win32::Shortcut.open(img).path
            # Get the real file extension now
            file_extension = File.extname(img)
          end
          begin
            date = File.basename(img, ".*").split("_")[0]
            parent_path = File.dirname(img)
            stitched_image = "#{stitched_images_path}/#{date}_full.jpg"
            enblend_tmp_file_prefix = "#{$camera_location}_#{date}_"
            nona_input_files_string = ""
            enblend_input_files_string = ""
            for i in 1..$num_images_to_stitch
              nona_input_files_string += " #{%Q{"#{parent_path}/#{date}_image#{i}#{file_extension}"}}"
              enblend_input_files_string += " #{enblend_tmp_file_prefix}#{'%04d' % (i-1)}.tif"
            end
            rets = []
            rets << system("#{$nona_path} -o #{enblend_tmp_file_prefix} #{%Q{"#{$stitcher_master_alignment_file}"}} #{nona_input_files_string}")
            if $use_multiblend_for_hugin
              rets << system("#{$multiblend_path} --compression=100 --wideblend --quiet -o #{%Q{"#{stitched_image}"}} #{enblend_input_files_string}")
            else
              rets << system("#{$enblend_path} --no-optimize --compression=100 --fine-mask -o #{%Q{"#{stitched_image}"}} #{enblend_input_files_string}")
            end
            Dir.glob("#{enblend_tmp_file_prefix}*.tif").each { |f| File.delete(f) }
            # If nona or enblend|multiblend crashes, we don't want to count this as a success. Also, delete the file it may have made.
            # TODO: We have seen multiblend crash occasionally. Perhaps it is worth retrying the stitch again. For now though, we just throw it out.
            if rets.include?(false)
              puts "[#{Time.now}] Error stitching images for #{date}."
              FileUtils.rm_f(stitched_image)
            else
              match_count += 1
            end
          rescue => e
            puts e
            # Ignore and move on
            # TODO: Maybe do something in this case.
          end
        end
      end
      puts "[#{Time.now}] Stitching complete. Stitched #{match_count} out of #{count} possible frames."
      $apply_mask ? apply_pano_mask : create_tm
    end
  end

  def apply_pano_mask
    puts "[#{Time.now}] Applying mask to frames."
    stitched_images_path = File.join($working_dir, "0100-original-images")
    files = Dir.glob("#{stitched_images_path}/*_full.*")
    Parallel.each(files, :in_threads => $num_jobs) do |img|
      begin
        system("#{$masker_path} #{img} #{$img_mask_inpaint_path} #{$img_mask_gaus_path} #{img}")
      rescue
        # Ignore and move on
        # TODO: Maybe do something in this case.
      end
    end
    puts "[#{Time.now}] Done applying mask to frames."
    create_tm
  end

  def create_top_video
    json = $definition_file

    fps = json["videosets"][0]["fps"]
    crf = json["videosets"][0]["quality"]
    video_type = json["videosets"][0]["type"]
    video_label = json["videosets"][0]["label"]
    video_dimensions = json["videosets"][0]["size"]
    tm_extra = 1.333333
    video_dimensions_with_extra = [(video_dimensions[0].to_i * tm_extra).ceil, (video_dimensions[1].to_i * tm_extra).ceil]

    top_video_length_in_sec = json["top_video_length_in_sec"]
    capture_time_parser = json["source"]["capture_time_parser"]

    dataset_path = "crf#{crf}-#{fps}fps-#{video_dimensions.join('x')}"
    input_images_path = File.join($working_dir, "0100-original-images")
    output_root_path = File.join($working_dir, $current_day + ".timemachine")
    output_video_path = File.join(output_root_path, dataset_path)
    output_video_tile_path = File.join(output_video_path, "overview")
    FileUtils.mkdir_p(output_video_tile_path)

    path_to_tm_file = "#{output_root_path}/tm.json"
    path_to_r_file = "#{output_video_path}/r.json"

    if not File.exists?(path_to_tm_file)
      File.open(path_to_tm_file, "w") do |fh|
        tm_json = {}
        tm_json['datasets'] = []
        datasets = {}
        datasets['id'] = dataset_path
        tm_json['datasets'].push(datasets)
        tm_json['sizes'] = video_label
        tm_json['id'] = $camera_location
        tm_json['capture-times'] = []
        fh.puts(JSON.dump(tm_json))
      end
    end
    tm_json = open(path_to_tm_file) {|fh| JSON.load(fh)}

    input_images = Dir.glob("#{input_images_path}/*{#{$valid_image_extensions.join(',')}}")

    if not File.exists?(path_to_r_file)
      input_image = input_images[0]
      input_image_dimensions = `identify -ping -format '%[width]x%[height]' #{input_image}`
      input_image_dimensions_array = input_image_dimensions.split('x')
      File.open(path_to_r_file, "w") do |fh|
        r_json = {}
        r_json['fps'] = fps
        fh.puts(JSON.dump(r_json))
      end
    end

    if video_type == "webm"
      codec = "libvpx"
      output_extension = "webm"
    else
      codec = "libx264 -profile:v baseline"
      output_extension = "mp4"
    end

    if top_video_length_in_sec
      num_new_images = input_images.length
      num_current_frames = tm_json["capture-times"].length
      max_frames = (top_video_length_in_sec / 60) * (60 / $image_capture_interval)
      frame_diff = (num_current_frames + num_new_images) - max_frames
    else
      frame_diff = 0
    end

    ffmpeg_output_command = "-s #{video_dimensions_with_extra.join('x')} -c:v #{codec} -preset ultrafast -pix_fmt yuv420p -crf #{crf} -bf 0 -g 10 -threads 16"

    system("#{$ffmpeg_path} -framerate #{fps} -pattern_type glob -i '#{input_images_path}/*.jpg' #{ffmpeg_output_command} #{output_video_tile_path}/0-1.#{output_extension}")

    inplace_append = true
    # Ensure only the last x amount of frames are stored in the video
    if frame_diff > 0
      inplace_append = false
      seconds_to_chop = frame_diff.to_f / fps.to_f
      concat_str = "file '#{output_video_tile_path}/0-0.#{output_extension}'\nfile '#{output_video_tile_path}/0-1.#{output_extension}'"
      system("echo \"#{concat_str}\" > /tmp/#{$camera_location}.concat.txt")
      system("#{$ffmpeg_path} -i #{output_video_tile_path}/0.#{output_extension} -ss #{seconds_to_chop} #{ffmpeg_output_command} #{output_video_tile_path}/0-0.#{output_extension}")
      system("#{$ffmpeg_path} -auto_convert 1 -f concat -safe 0 -i /tmp/#{$camera_location}.concat.txt #{ffmpeg_output_command} #{output_video_tile_path}/0-new.#{output_extension}")
      new_tm_json["capture-times"].shift(frame_diff)
    else
      if File.exists?("#{output_video_tile_path}/0.#{output_extension}")
        system("#{$mp4_concat_path} #{output_video_tile_path}/0.#{output_extension} #{output_video_tile_path}/0-1.#{output_extension} --future_frames=#{$future_appending_frames}")
        ####concat_str = "file '#{output_video_tile_path}/0.#{output_extension}'\nfile '#{output_video_tile_path}/0-1.#{output_extension}'"
        ####system("echo \"#{concat_str}\" > /tmp/#{$camera_location}.concat.txt")
        # Note: Cannot use -c copy since it results in a video that has playback issues in Chrome. Gets stuck buffering while scrubbing/seeking. Not sure why this is.
        ####system("#{$ffmpeg_path} -auto_convert 1 -f concat -safe 0 -i /tmp/#{$camera_location}.concat.txt #{ffmpeg_output_command} #{output_video_tile_path}/0-new.#{output_extension}")
      else
        inplace_append = false
        FileUtils.mv("#{output_video_tile_path}/0-1.#{output_extension}", "#{output_video_tile_path}/0-new.#{output_extension}", :force => true)
      end
    end

    if inplace_append
      system("#{$qtfaststart_path} #{output_video_tile_path}/0.#{output_extension}")
    else
      system("#{$qtfaststart_path} #{output_video_tile_path}/0-new.#{output_extension}")
      FileUtils.mv("#{output_video_tile_path}/0-new.#{output_extension}", "#{output_video_tile_path}/0.#{output_extension}", :force => true)
    end

    current_capture_times = tm_json["capture-times"]
    system("ruby #{capture_time_parser} #{input_images_path} #{path_to_tm_file}")
    new_tm_json = open(path_to_tm_file) {|fh| JSON.load(fh)}
    new_capture_times = new_tm_json["capture-times"]
    new_tm_json["capture-times"] = current_capture_times + new_capture_times

    tmp_tm_file = path_to_tm_file + ".tmp"
    open(tmp_tm_file, "w") {|fh| fh.puts(JSON.generate(new_tm_json))}
    File.rename(tmp_tm_file, path_to_tm_file)

    FileUtils.rm_f(File.join(output_video_tile_path, "0-0.#{output_extension}"))
    FileUtils.rm_f(File.join(output_video_tile_path, "0-1.#{output_extension}"))
  end

  def create_tm
    # Image directory is ready now that we are at this step
    FileUtils.touch(File.join($working_dir, "0100-original-images", "DONE"))
    if $create_top_video_only
      create_top_video
    else
      puts "[#{Time.now}] Creating Time Machine..."
      tm_name = $current_day.blank? ? $camera_location : ($is_monthly ? Date.parse($current_day).beginning_of_month.to_s : $current_day)
      $timemachine_output_dir = $create_videoset_segment_directory ? "#{tm_name}-#{$incremental_update_interval}m.timemachine" : "#{tm_name}.timemachine"
      # If the *.timemachine directory already exists, remove it since ct.rb will most likely become confused and not make new video tiles
      FileUtils.rm_rf("#{$timemachine_output_path}/#{$timemachine_output_dir}")
      $timemachine_master_output_dir = "#{tm_name}.timemachine"
      extra_flags = ""
      extra_flags += "--skip-trailer " if $skip_trailer
      extra_flags += "--skip-leader " if $skip_leader
      extra_flags += "--skip-videos --preserve-source-tiles " if $skip_videos
      extra_flags += "--sort-by-exif-dates " if $sort_by_exif_dates
      extra_flags += "-tile-mode #{$video_tile_mode} " if $video_tile_mode
      # TODO: Assumes Ruby is installed and ct.rb is in the PATH
      Dir.chdir($working_dir) do
        puts "ct.rb #{$working_dir} #{$timemachine_output_path}/#{$timemachine_output_dir} -j #{$num_jobs} #{extra_flags}"
        system("ct.rb #{$working_dir} #{$timemachine_output_path}/#{$timemachine_output_dir} -j #{$num_jobs} #{extra_flags}") or raise "[#{Time.now}] Error encountered processing Time Machine. Exiting."
      end
      puts "[#{Time.now}] Time Machine created."
      add_entry_to_json
      append_new_segments if $append_inplace or (!$append_inplace and $create_videoset_segment_directory)
      rsync_location_json if $rsync_location_json
      rsync_tile_tree_if_necessary unless $is_monthly
    end
    trim_ssd if $force_trim_on_working_dir
    run_image_mse_checker if $calculate_image_mse
    completed_process
  end

  def add_entry_to_json
    json = {}
    path_to_json = "#{$working_dir}/#{$camera_location}.json"
    path_to_js = "#{$working_dir}/#{$camera_location}.js"
    if File.exists?(path_to_json)
      json = open(path_to_json) {|fh| JSON.load(fh)}
    else
      json["location"] = camera_name_remap($camera_location)
      json["split_type"] = $is_monthly ? "monthly" : "daily"
      json["datasets"] = {}
    end
    new_latest = $current_day
    if json["latest"] && json["latest"]["date"]
      last_latest = json["latest"]["date"]
      last_latest_array = last_latest.split("-")
      date_array = $current_day.split("-")
      last_latest_year = last_latest_array[0].to_i
      last_latest_month = last_latest_array[1].to_i
      last_latest_day = last_latest_array[2].to_i
      date_year = date_array[0].to_i
      date_month = date_array[1].to_i
      date_day = date_array[2].to_i
      new_latest = last_latest if ((last_latest_year > date_year) || (last_latest_year >= date_year && last_latest_month > date_month) || (last_latest_year >= date_year && last_latest_month >= date_month && last_latest_day > date_day))
    else
      json["latest"] = {}
    end
    latest_entry = $is_monthly ? Date.parse($current_day).beginning_of_month.to_s : new_latest
    dateset_entry = $is_monthly ? Date.parse($current_day).beginning_of_month.to_s : $current_day
    json["latest"]["date"] = new_latest
    json["latest"]["path"] = File.join($root_tile_url, $camera_location, "#{latest_entry}.timemachine")
    json["datasets"]["#{$current_day}"] = File.join($root_tile_url, $camera_location, "#{dateset_entry}.timemachine")
    tmp_time = Time.zone.now
    tmp_path_to_json = path_to_json + "_#{tmp_time}"
    tmp_path_to_js = path_to_js + "_#{tmp_time}"
    open(tmp_path_to_json, "w") {|fh| fh.puts(JSON.generate(json))}
    open(tmp_path_to_js, "w") {|fh| fh.puts("cached_breathecam=" + JSON.generate(json) + ";")}
    FileUtils.mv(tmp_path_to_json, path_to_json, :force => true)
    FileUtils.mv(tmp_path_to_js, path_to_js, :force => true)
    puts "Successfully wrote #{$camera_location}.json"
  end

  def append_new_segments
    output_path = $timemachine_output_path
    if $append_inplace
      append_and_cut_inplace("#{output_path}/#{$timemachine_master_output_dir}", "#{output_path}/#{$timemachine_output_dir}", !$create_videoset_segment_directory)
    else
      append_and_cut("#{output_path}/#{$timemachine_master_output_dir}", "#{output_path}/#{$timemachine_output_dir}")
    end
  end

  def append_and_cut_inplace(path_to_master_videoset, path_to_new_videoset, suffix_only)
    FileUtils.touch(File.join($working_dir, "WIP2"))

    # This file is a set of 10 black frames. It is 10 frames long because we insert a keyframe every 10 frames
    # and this matches a full chunk in the mp4 file, which we append to the end if necessary.
    path_to_trailer = File.join($CURRENT_SCRIPT_PATH, "suffix_10_600p.mp4")
    master_videos = Dir.glob("#{path_to_master_videoset}/crf*/*/*/*.mp4").sort

    # TODO: if skip_trailer is true, this means that we are not producing extra black frames in each segment
    # This code assumes that to be the case and handles adding in these trailing black frames. It's not clear
    # that we even need these extra frames anymore to deal with browser bugs. I don't even recall what those bugs were...
    # That said, we can't use this same flag to disable appending trailing frames entirely and need yet another one.
    if suffix_only
      puts "[#{Time.now}] Appending black frames to initial master set."
      Parallel.each_with_index(master_videos, :in_threads => $num_jobs) do |master_video, index|
        # Take master and append the black frame chunk to it. Also prepare the file for future frames.
        unless system("#{$mp4_concat_path} #{master_video} #{path_to_trailer} --future_frames=#{$future_appending_frames}")
          puts "[#{Time.now}] Error first time appending frames to master set."
          exit
        end
      end
    else
      puts "[#{Time.now}] Appending current set to master video files."

      path_to_master_r_json = Dir.glob("#{path_to_master_videoset}/crf*/r.json").first
      path_to_new_r_json = Dir.glob("#{path_to_new_videoset}/crf*/r.json").first
      path_to_master_tm_json = "#{path_to_master_videoset}/tm.json"
      path_to_new_tm_json = "#{path_to_new_videoset}/tm.json"
      path_to_ajax_includes = "#{path_to_master_videoset}/ajax_includes.js"
      path_to_ajax_includes_updater = "#{path_to_master_videoset}/update_ajax_includes.rb"

      master_r_json = open(path_to_master_r_json) {|fh| JSON.load(fh)}
      num_frames = master_r_json["frames"].to_f

      new_r_json = open(path_to_new_r_json) {|fh| JSON.load(fh)}
      additional_frame_count = new_r_json["frames"].to_i

      next_segment_videos = Dir.glob("#{path_to_new_videoset}/crf*/*/*/*.mp4").sort

      # Note: This assumes each segment has the same number of tiles. If image resolution changes between segment processing, then this will break.
      Parallel.each_with_index(master_videos, :in_threads => $num_jobs) do |master_video, index|
        next_segment_video = next_segment_videos[index]
        # Take master without the black frame chunk at the end, append the new segment, and then append the black frame chunk
        # We can make use of python-style slicing, so [0:-1] excludes the last chunk of the master, which removes the 10 frame trailer.
        unless system("#{$mp4_concat_path} '#{master_video}[0:-1]' #{next_segment_video} #{path_to_trailer}")
          puts "[#{Time.now}] Error appending additional frames to master set."
          exit
        end
      end

      tmp_time = Time.zone.now

      # Update r.json with the new number of frames being added.
      new_total_frames = num_frames.to_i + additional_frame_count
      master_r_json["frames"] = new_total_frames
      tmp_path_to_master_r_json = path_to_master_r_json + "_#{tmp_time}"
      open(tmp_path_to_master_r_json, "w") {|fh| fh.puts(JSON.pretty_generate(master_r_json))}
      FileUtils.mv(tmp_path_to_master_r_json, path_to_master_r_json, :force => true)

      # Update tm.json with capture times for the new frames being added.
      master_tm_json = open(path_to_master_tm_json) {|fh| JSON.load(fh)}
      new_tm_json = open(path_to_new_tm_json) {|fh| JSON.load(fh)}
      master_tm_json["capture-times"] += new_tm_json["capture-times"] if new_tm_json["capture-times"]
      tmp_path_to_master_tm_json = path_to_master_tm_json + "_#{tmp_time}"
      open(tmp_path_to_master_tm_json, "w") {|fh| fh.puts(JSON.generate(master_tm_json))}
      FileUtils.mv(tmp_path_to_master_tm_json, path_to_master_tm_json, :force => true)

      # Update ajax_includes.js based on the new changes made to the json above.
      system("ruby #{path_to_ajax_includes_updater}")

      # Remove the new set since we just finished appending it to the master.
      FileUtils.rm_rf("#{path_to_new_videoset}")
    end

    # No qt-faststart required, since Concatenate-mp4-videos.py already does the work and in fact, running qt-faststart
    # at this point removes the free buffer just added, which was there to speed up future appends.

    puts "[#{Time.now}] Finished inplace appending new files."

    FileUtils.rm(File.join($working_dir, "WIP2"))
  end

  def append_and_cut(path_to_master_videoset, path_to_new_videoset)
    FileUtils.touch(File.join($working_dir, "WIP2"))
    puts "[#{Time.now}] Cutting garbage frames from the beginning/end and then appending current set to master video files."
    path_to_master_r_json = Dir.glob("#{path_to_master_videoset}/crf*/r.json").first
    path_to_new_r_json = Dir.glob("#{path_to_new_videoset}/crf*/r.json").first
    path_to_master_tm_json = "#{path_to_master_videoset}/tm.json"
    path_to_new_tm_json = "#{path_to_new_videoset}/tm.json"
    path_to_ajax_includes = "#{path_to_master_videoset}/ajax_includes.js"
    path_to_ajax_includes_updater = "#{path_to_master_videoset}/update_ajax_includes.rb"

    if File.exists?(path_to_master_r_json) and File.exists?(path_to_new_r_json) and File.exists?(path_to_ajax_includes) and File.exists?(path_to_ajax_includes_updater) and File.exists?(path_to_master_tm_json) and File.exists?(path_to_new_tm_json)
      master_r_json = open(path_to_master_r_json) {|fh| JSON.load(fh)}
      num_frames = master_r_json["frames"].to_f
      fps = master_r_json["fps"].to_f
      leader_for_master = master_r_json["leader"].to_f
      vid_width = master_r_json["video_width"].to_f
      vid_height = master_r_json["video_height"].to_f
      end_frame_for_master = num_frames

      new_r_json = open(path_to_new_r_json) {|fh| JSON.load(fh)}
      additional_frame_count = new_r_json["frames"].to_i
      leader_for_next_segment = new_r_json["leader"].to_f
      start_time_for_next_segment = leader_for_next_segment.floor / fps

      master_videos = Dir.glob("#{path_to_master_videoset}/crf*/*/*/*.mp4").sort
      next_segment_videos = Dir.glob("#{path_to_new_videoset}/crf*/*/*/*.mp4").sort

      if master_videos.length != next_segment_videos.length
        puts "Different number of videos between sets. Aborting."
        return
      end

      if $skip_leader
        new_leader = 0
        add_leader = false
      else
        # TODO: We assume the leader is always 70 frames. It would be nice to actually calculate it
        # and create these frames on the fly, rather than use a pre-computed file.
        # It is faster this way, but we cannot always assume this fixed size, which is only true
        # for a day of breathecam.
        leader_path = File.join($CURRENT_SCRIPT_PATH, "leader_70_600p.mp4")
        leader_bytes_per_pixel={
          30 => 2701656.0 / (vid_width * vid_height * 90),
          28 => 2738868.0 / (vid_width * vid_height * 80),
          26 => 2676000.0 / (vid_width * vid_height * 70),
          24 => 2556606.0 / (vid_width * vid_height * 60)
        }
        bytes_per_frame = vid_width * vid_height * leader_bytes_per_pixel[26]
        leader_threshold = 1200000
        estimated_video_size = bytes_per_frame * num_frames
        add_leader = false
        if estimated_video_size < leader_threshold
          new_leader = 0
        else
          minimum_leader_length = 2500000
          leader_nframes = minimum_leader_length / bytes_per_frame
          # Round up to nearest multiple of frames per keyframe
          frames_per_keyframe = 10
          leader_nframes = (leader_nframes / frames_per_keyframe).ceil * frames_per_keyframe
          # The last two frames of the leader are actually dups of the first frames of the real video.
          # Since we are using a pre-computed leader video (that does not include this), we need to take this into account.
          # We subtract 1.9 (rather than 2) because browsers will show the leader if we go right up to the first frame of the video.
          # This value prevents the leader from showing and prevents the first of the last 10 black frames from peeking through. Sigh.
          new_leader = leader_nframes - 1.9
          actual_leader = leader_nframes - 2.0
          # The first time we add the leader we do not want to modify the start time, since
          # this assumes a leader is already present in the master video.
          if leader_for_master > 0
            end_frame_for_master = actual_leader + num_frames
          else
            add_leader = true
          end
        end
        # END TODO
      end

      Parallel.each_with_index(master_videos, :in_threads => $num_jobs) do |video, index|
        next_segment_video = next_segment_videos[index]

        # Create a temp video file from the master that has the leader and black frames at the end removed.
        # We need double forward slashes for a links inside the .txt file below for things to work on Windows. Odd.
        tmp_master = "#{File.dirname(video)}/#{File.basename(video,'.*')}-cut.mp4"
        system("ffmpeg -y -i #{video} -vframes #{end_frame_for_master} -vcodec copy -acodec copy #{tmp_master}")

        # Create a temp video from the new file without a leader included but does still have black frames at the end.
        # We need double forward slashes for a links inside the txt file below for things to work on Windows. Odd.
        if start_time_for_next_segment > 0.0
          tmp_new_video = "#{File.dirname(next_segment_video)}/#{File.basename(next_segment_video,'.*')}-cut.mp4"
          system("ffmpeg -y -i #{next_segment_video} -ss #{start_time_for_next_segment} -vcodec copy -acodec copy #{tmp_new_video}")
        else
          tmp_new_video = next_segment_video
        end

        tmp_final_video = "#{File.dirname(video)}/#{File.basename(video,'.*')}-tmp.mp4"

        # If needed, we include the leader in the append below. This is only done once.
        leader_concat_command = add_leader ? "#{leader_path}.ts|" : ""

        # Append the leader (if needed), the master, and the next set of frames. We accomplish this by first doing an intermediate step of transcoding to mpeg transport streams and then concatenating. This makes use ffmpegs concat protocol.
        # Note: It seems that the demuxer protocol causes the fps of the final concatenated video to be incorrect (off by some %; i.e. 11.99 vs 12.0)
        system("ffmpeg -i #{tmp_master} -c copy -bsf:v h264_mp4toannexb -f mpegts #{tmp_master}.ts; ffmpeg -i #{tmp_new_video} -c copy -bsf:v h264_mp4toannexb -f mpegts #{tmp_new_video}.ts; ffmpeg -i 'concat:#{leader_concat_command}#{tmp_master}.ts|#{tmp_new_video}.ts' -c copy -bsf:a aac_adtstoasc #{tmp_final_video}")

        # Rename temp video to final video
        FileUtils.mv(tmp_final_video, video)

        # Remove the temp files
        File.delete(tmp_master)
        File.delete(tmp_master + ".ts")
      end

      tmp_time = Time.zone.now

      # Update r.json with the new number of frames being added.
      master_r_json["frames"] = num_frames.to_i + additional_frame_count
      master_r_json["leader"] = new_leader
      tmp_path_to_master_r_json = path_to_master_r_json + "_#{tmp_time}"
      open(tmp_path_to_master_r_json, "w") {|fh| fh.puts(JSON.pretty_generate(master_r_json))}
      FileUtils.mv(tmp_path_to_master_r_json, path_to_master_r_json, :force => true)

      # Update tm.json with capture times for the new frames being added.
      master_tm_json = open(path_to_master_tm_json) {|fh| JSON.load(fh)}
      new_tm_json = open(path_to_new_tm_json) {|fh| JSON.load(fh)}
      master_tm_json["capture-times"] += new_tm_json["capture-times"]
      tmp_path_to_master_tm_json = path_to_master_tm_json + "_#{tmp_time}"
      open(tmp_path_to_master_tm_json, "w") {|fh| fh.puts(JSON.generate(master_tm_json))}
      FileUtils.mv(tmp_path_to_master_tm_json, path_to_master_tm_json, :force => true)

      # Update ajax_includes.js based on the new changes made to the json above.
      system("ruby #{path_to_ajax_includes_updater}")

      FileUtils.rm(File.join($working_dir, "WIP2"))

      # Run qt-faststart. ffmpeg should be able to do this with '-movflags faststart' but apparently it does not actually do it.
      # TODO: We assume qtfaststart is in the PATH
      # Once we go past 5pm or so, our appends may take too long to also run qt-faststart in our 10 min window.
      # So, we skip the following for the time being and do it again once we rsync over the next day.
      unless $skip_qtfaststart_append
        curr_hour = Time.zone.now.hour
        if curr_hour < 17 and (curr_hour != 0 or $current_day == Date.today.to_s)
          run_qtfaststart(path_to_master_videoset)
        end
      end

      # Remove the new set since we just finished appending it to the master.
      FileUtils.rm_rf("#{path_to_new_videoset}")

      puts "[#{Time.now}] Finished appending new files."
    else
      if !File.exists?(path_to_master_r_json)
        puts "Did not find r.json for the master videoset."
      elsif !File.exists?(path_to_new_r_json)
        puts "Did not find r.json for the new videoset."
      elsif !File.exists?(path_to_ajax_includes)
        puts "Did not find ajax_includes.js for the master videoset"
      elsif !File.exists?(path_to_ajax_includes_updater)
        puts "Did not find update_ajax_includes.rb for the master videoset."
      elsif !File.exists?(path_to_master_tm_json)
        puts "Did not find tm.json for the master videoset."
      elsif !File.exists?(path_to_new_tm_json)
        puts "Did not find tm.json for the new videoset."
      end
    end
  end

  def run_qtfaststart(path_to_master_videoset)
    puts "[#{Time.now}] Running qt-faststart"
    system("find #{path_to_master_videoset}/crf*/ -type f -name '*.mp4' -exec qtfaststart {} \\;")
  end

  def rsync_tile_tree_if_necessary
    remote_symlink_path = "''"
    if $rsync_output_info['symlink_root']
      remote_symlink_path = "#{$rsync_output_info['symlink_root']}/#{$camera_location}"
    end

    image_paths_to_delete = "''"
    if $rsync_output_info['delete_input_images']
      image_paths_to_delete = $camera_paths.join(',')
    end

    local_img_src_mnt = "''"
    if $rsync_output_info['local_img_src_mnt']
      local_img_src_mnt = $rsync_output_info['local_img_src_mnt']
    end

    rsync_by_increment = !!$rsync_output_info['rsync_by_increment']

    dest_path = "#{$rsync_output_info['dest_root']}/#{$camera_location}"

    # If we are no longer the day we started with, this means we are now the next day.
    # Also check how many frames we processed. This is kinda arbitrary since we can have a few situations where less frames than expected get processed.
    #   We start a run much later in the day, with the intent to reprocess at some point. How to deal with that?
    #      This is manual intervention so it's on us to re-process.
    #   Matching images get confused and we end up processing much less than we should and we need to redo the day. How to deal with that?
    #      Ensure matching is always happy...not easy since if a camera lags behind, images can come in very staggered.
    if $initial_last_pull_time and Time.zone.parse($end_time["full"]).beginning_of_day != $initial_last_pull_time.beginning_of_day
      path_to_master_r_json = Dir.glob("#{$working_dir}/#{$initial_current_day}.timemachine/crf*/r.json").first
      master_r_json = open(path_to_master_r_json) {|fh| JSON.load(fh)}
      num_frames = master_r_json["frames"].to_f
      # If we are only missing at most N% of total frames, we call success for the day
      if num_frames > ($future_appending_frames - ($future_appending_frames * $percent_accepted_frame_loss)).round
        puts "Turned over to a new day, #{num_frames} frames were processed. Run rsync script."
        # Note: Assumes no commas in camera paths
        cmd = "run-one ruby #{$rsync_script} #{$working_dir} #{dest_path} #{$rsync_output_info['host']} #{remote_symlink_path} #{$initial_current_day} #{image_paths_to_delete} #{local_img_src_mnt} #{$rsync_output_info['log_file_root']}/#{$camera_location}-rsync.log #{rsync_by_increment}"
        puts cmd
        pid = fork do
          exec(cmd)
          exit
        end
        Process.detach(pid)
      else
        puts "Turned over to a new day, but only #{num_frames} frames were processed. No rsyncing or original image deletion will happen for #{$initial_current_day}."
      end
    elsif rsync_by_increment
      src_tm_path  = "#{$working_dir}/#{$initial_current_day}.timemachine"
      year_month_day = $initial_current_day.split("-")
      parent_output_path = remote_symlink_path == "''" ? "#{dest_path}" : "#{dest_path}/#{year_month_day[0]}/#{year_month_day[1]}"
      final_output_tm_path = "#{parent_output_path}/#{$initial_current_day}.timemachine"

      remote_command = "mkdir -p #{parent_output_path}"
      remote_command += "; ln -s #{final_output_tm_path} #{remote_symlink_path}/#{$initial_current_day}.timemachine" if remote_symlink_path != "''" && !$create_videoset_segment_directory

      cmd = "rsync -a --rsync-path='#{remote_command} && rsync' #{src_tm_path}/ #{$rsync_output_info['host']}:/#{final_output_tm_path}"
      puts cmd
      is_success = system(cmd)
      if is_success
        puts "Successfully rsynced latest processed increment."
      else
        puts "Error rsyncing."
        exit
      end
    end
  end

  def rsync_location_json
    if !$create_videoset_segment_directory || $is_monthly
      location_json_output_path = $output_path
      if $rsync_output_info['symlink_root']
        location_json_output_path = "#{$rsync_output_info['host']}:#{$rsync_output_info['symlink_root']}/#{$camera_location}"
      end
      puts "[#{Time.now}] Rsyncing #{$camera_location}.js{on} to #{location_json_output_path}"
      args = location_json_output_path.split(":")
      if args.length > 1
        host = args[0]
        src_path = args[1]
        extra_ssh_command = "source .profile;"
        tm_name = $is_monthly ? Date.parse($current_day).beginning_of_month.to_s : nil
        cmd = "ssh #{host} \"#{extra_ssh_command} modify_breathecam_json.rb #{src_path} #{$root_tile_url} #{$camera_location} #{$current_day} #{tm_name}\""
      else
        cmd = "rsync -a #{$working_dir}/#{$camera_location}.json #{$working_dir}/#{$camera_location}.js #{location_json_output_path}"
      end
      puts cmd
      system(cmd)
    end
  end

  def trim_ssd
    mount_point = File.dirname($working_dir)
    puts "[#{Time.now}] Trimming #{mount_point}"
    system("sudo fstrim -v #{mount_point}")
  end

  def run_image_mse_checker
    # TODO: Deal with hardcoded path to conda
    puts "[#{Time.now}] Calculating MSE for input images."
    for i in 0..$camera_list.length-1
      file_ext = File.extname($mse_golden_images[i]).delete(".")
      match = $camera_list[i].match(/\/(#{$camera_location}.*)\//)
      if match
        system("bash -c '. /home/pdille/.bashrc_conda; conda activate image-diff; python #{$image_diff_path} #{$mse_golden_images[i]} #{$working_dir}/050-raw-images/#{i} #{file_ext} #{match[1]} #{$current_day} #{$working_dir}/#{$camera_location}_rolling_results.json'")
      end
    end
  end

  def completed_process
    puts "[#{Time.now}] Process Finished Successfully."
    puts "End Time: #{Time.now}"
  end

  def usage
    puts "Basic usage: ruby create_breathe_cam_tm.rb PATH_TO_DEFINITION_FILE"
    exit
  end

end

compiler = Compiler.new(ARGV)
