#!/usr/bin/env ruby

# Create a time machine from breathecam imagery

require 'fileutils'
require 'logger'
require 'date'
require 'json'
require 'shellwords'
require File.join(File.dirname(__FILE__), 'thread-pool')

# Logging
$verbose = false
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

$RUNNING_WINDOWS = /(win|w)32$/.match(RUBY_PLATFORM)
$RUNNING_MAC = RUBY_PLATFORM.downcase.include?("darwin")
$RUNNING_LINUX = RUBY_PLATFORM.downcase.include?("linux")

# For lossless image rotations
$jpegtran_path = $RUNNING_WINDOWS ? "jpegtran.exe" : "jpegtran"

# Hugin tools
$nona_path = $RUNNING_WINDOWS ? "nona.exe" : "nona"
$enblend_path = $RUNNING_WINDOWS ? "enblend.exe" : "enblend"

$valid_image_extensions = [".jpg", ".lnk"]
$default_num_jobs = 4
$thread_pool = nil
$rsync_input = false
$rsync_output = false
$tmp_output_path = nil

if $RUNNING_WINDOWS
  require File.join(File.dirname(__FILE__), 'shortcut')
end

class Compiler
  def initialize(args)

    if args.length < 4
      usage
    end

    if File.exists?(File.join("#{$camera_location}","WIP"))
      puts "A file called 'WIP' was detected, which indicates that this working directory is already in the middle of processing. Aborting."
      exit
    end

    current_time = Time.now
    puts "Start Time: #{current_time}"

    $end_time = {}
    $end_time["hour"] = current_time.strftime("%H").to_i
    $end_time["minute"] = current_time.strftime("%M").to_i

    $input_path = ARGV[0]
    $output_path = ARGV[1]
    $master_alignment_file = ARGV[2]
    $camera_location = ARGV[3]

    unless $input_path
      puts "Input path not provided."
      usage
    end

    unless $output_path
      puts "Output path not provided."
      usage
    end

    unless $master_alignment_file
      puts "Hugin alignment file not provided."
      usage
    end

    unless $camera_location
      puts "Camera location (e.g. heinz) not provided"
      usage
    end

    $working_dir = File.join(File.dirname(__FILE__), "#{$camera_location}.tmc")

    while !ARGV.empty?
      arg = ARGV.shift
      if arg == "-j"
        $num_jobs = ARGV.shift.to_i
      elsif arg == "--rsync-input"
        $rsync_input = true
      elsif arg == "--rsync-output"
        $rsync_output = true
      elsif arg == "-current-day"
        $current_day = ARGV.shift
      elsif arg == "-incremental-update-interval"
        # Force interval to be a multiple of 10.
        # This is needed because we add a keyframe every 10 frames
        # and thus do not need to worry about it when appending if we
        # keep it this way.
        $incremental_update_interval = (ARGV.shift.to_f / 10.0).ceil * 10
      end
    end

    $do_incremental_update = true if defined?($incremental_update_interval)

    if $current_day and $do_incremental_update
      puts "Specifying a day AND doing incremental appending is not supported. You can only do incremental appending from the actual day of running the script. \n So, either just specify a day OR specify incremental updating."
      exit
    end

    $num_jobs ||= $default_num_jobs

    # If a date to process was not specified, then choose today if we are doing
    # incremental updates, otherwise do the previous day (since we have all images for that)
    $current_day ||= ($do_incremental_update ? Date.today : (Date.today - 1)).to_s

    # Clean up paths if coming from Windows
    $input_path = $input_path.tr('\\', "/").chomp("/")
    $output_path = $output_path.tr('\\', "/").chomp("/")

    if !$rsync_input && !File.exists?(File.expand_path($input_path))
      puts "Invalid input path: #{$input_path}"
      exit
    end

    $timemachine_output_path = $rsync_output ? $working_dir : $output_path

    puts "Starting process."

    $thread_pool = Pool.new($num_jobs)

    at_exit do
      $thread_pool.shutdown
      FileUtils.rm(File.join($working_dir,"WIP"))
    end

    FileUtils.mkdir_p($working_dir)
    FileUtils.touch(File.join($working_dir,"WIP"))
    calculate_rsync_input_range if $do_incremental_update
    clear_working_dir
    $rsync_input ? rsync_source_images : organize_images
  end

  def calculate_rsync_input_range
    $start_time = {}
    $start_time["hour"] = $end_time["hour"]
    $start_time["minute"] = $end_time["minute"] - $incremental_update_interval
    if $start_time["minute"] < 0
      hour_diff = ($start_time["minute"].abs / 60.0).ceil
      $start_time["hour"] = $end_time["hour"] - hour_diff
      $start_time["minute"] = (60 * hour_diff) - $start_time["minute"].abs
      if $start_time["hour"] < 0
        video_sets = Dir.glob("#{$timemachine_output_path}/*.timemachine").sort
        day_diff = ($start_time["hour"] / 24.0).abs.ceil
        tmp_current_day = $current_day
        tmp_current_day -= day_diff
        # If we need to backtrack the day.
        if video_sets.first.include?(tmp_current_day)
          $current_day = tmp_current_day
          $start_time["hour"] = 24 - hour_diff
        else
          # We just started incremental updating (with no other set from the current date)
          # and the update interval lands us on the current time. So, start and end times match
          # and in the end we will not be pulling images until the next interval.
          $start_time["hour"] = $end_time["hour"]
          $start_time["minute"] = $end_time["minute"]
        end
      end
    end
  end

  def clear_working_dir
    puts "Removing previous working files..."
    FileUtils.rm_rf("#{$working_dir}/050-raw-images")
    FileUtils.rm_rf("#{$working_dir}/075-organized-raw-images")
    FileUtils.rm_rf("#{$working_dir}/0100-original-images")
    # Hal specific:
    # These directories are already set to symlinks with the ssd on Hal,
    # so we just clear the old contents and start fresh.
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0200-tiles/*"))
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0300-tilestacks/*"))
    video_sets = Dir.glob("#{$timemachine_output_path}/*.timemachine").sort
    if $do_incremental_update
      if video_sets.length == 1
        if video_sets.first.include?($current_day)
          $create_videoset_segment_directory = true
        else
          # Old day lingering, wipe it out.
          FileUtils.rm_rf(Dir.glob("#{$working_dir}/*.timemachine"))
          FileUtils.rm_rf(Dir.glob("#{$timemachine_output_path}/*-#{$incremental_update_interval}m.timemachine"))
        end
      elsif video_sets.length == 2
        if video_sets.first.include?($current_day)
          $create_videoset_segment_directory = true
          # Still on the current day, so wipe out only the previous incremental segment
          FileUtils.rm_rf(Dir.glob("#{$timemachine_output_path}/#{$current_day}-#{$incremental_update_interval}m.timemachine"))
        else
          # Tis a new day, so wipe out everything
          FileUtils.rm_rf(Dir.glob("#{$working_dir}/*.timemachine"))
          FileUtils.rm_rf(Dir.glob("#{$timemachine_output_path}/*-#{$incremental_update_interval}m.timemachine"))
        end
      end
    else
      # Default daily processing, wipe out everything
      FileUtils.rm_rf(Dir.glob("#{$working_dir}/*.timemachine"))
      FileUtils.rm_rf(Dir.glob("#{$timemachine_output_path}/*-#{$incremental_update_interval}m.timemachine"))
    end
    puts "Finished removing old files."
  end

  def rsync_source_images
    puts "Rsycning images from #{$input_path}/#{$current_day}"
    new_input_path = File.join($working_dir, "050-raw-images")
    FileUtils.mkdir_p(new_input_path)

    if $do_incremental_update
      args = $input_path.split(":")
      host = args[0]
      src_path = args[1]
      system("ssh #{host} \"find #{src_path} -name '*.jpg' -newermt '#{$current_day} #{'%02d' % $start_time['hour']}:#{'%02d' % $start_time['minute']}:00' ! -newermt '#{$current_day} #{'%02d' % $end_time['hour']}:#{'%02d' % $end_time['minute']}:00' -printf '%f\n' > /tmp/#{$camera_location}-files.txt\"")
      system("rsync -a --files-from=:/tmp/#{$camera_location}-files.txt #{$input_path}/#{$current_day}/ #{new_input_path}")
    else
      # Else grab the entire day of images
      system("rsync -a #{$input_path}/#{$current_day}/*.jpg #{new_input_path}")
    end

    # We need to reference files locally now that we have rsynced everything over
    $input_path = new_input_path
    puts "Finished rsyncing input images."
    organize_images
  end

  def organize_images
    $organized_images_path = File.join($working_dir, "075-organized-raw-images")
    count = 0
    match_count = 0
    puts "Organizing images..."
    images = Dir.glob("#{$input_path}/*_image1.jpg").sort
    num_images_being_processed = images.length
    if num_images_being_processed == 0
      puts "No images found to be processed. Aborting."
      exit
    end
    images.each do |img|
      count += 1
      date = File.basename(img, ".*").split("_")[0]
      unless File.exists?("#{$input_path}/#{date}_image2.jpg") && File.exists?("#{$input_path}/#{date}_image3.jpg") && File.exists?("#{$input_path}/#{date}_image4.jpg")
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
      # Note: Windows Vista+ does support something that is essentially a symlink, but for now we will just stick with shortcuts that have worked with all versions of Windows
      if $RUNNING_WINDOWS
        for i in 1..4
          Win32::Shortcut.new("#{dir}/#{date}_image#{i}" + ".lnk") do |s|
            # Windows only supports absolute shortcut paths, in order to get them to be relative we need a special program: http://www.csparks.com/Relative/index.html
            s.path = "#{path}/#{date}_image#{i}.jpg"
            s.show_cmd = Win32::Shortcut::SHOWNORMAL
            s.working_directory = Dir.getwd
          end
        end
      else
        for i in 1..4
          File.symlink(File.expand_path("#{path}/#{date}_image#{i}.jpg"),"#{dir}/#{date}_image#{i}.jpg")
        end
      end
      match_count += 1
    end
    puts "Organizing complete. Matched #{match_count} out of #{count} possible frames."
    rotate_images
  end

  def rotate_images
    rot_amt = 180
    count = 0
    match_count = 0
    puts "Rotating images #{rot_amt} degrees clockwise..."
    files = Dir.glob("#{$organized_images_path}/*/*.*").sort
    num_jobs = files.length
    completed_jobs = 0
    files.each do |img|
      $thread_pool.schedule do
        next unless $valid_image_extensions.include? File.extname(img).downcase
        count += 1
        img = Win32::Shortcut.open(img).path if $RUNNING_WINDOWS && File.extname(img) == ".lnk"
        begin
          system("#{$jpegtran_path} -copy all -rotate #{rot_amt} -optimize -outfile  #{%Q{"#{img}"}} #{%Q{"#{img}"}}")
          match_count += 1
          completed_jobs += 1
        rescue
          # Ignore and move on
          # TODO:
          # Maybe do something in this case.
        end
      end
    end
    while completed_jobs != num_jobs
      # wait
    end
    puts "Rotating complete. Rotated #{match_count} out of #{count} images."
    stitch_images
  end

  def stitch_images
    count = 0
    match_count = 0
    puts "Stitching images..."
    $stitched_images_path = File.join($working_dir, "0100-original-images")
    files = Dir.glob("#{$organized_images_path}/*/*_image1.*").sort
    num_jobs = files.length
    completed_jobs = 0
    files.each do |img|
      $thread_pool.schedule do
        next unless $valid_image_extensions.include? File.extname(img).downcase
        count += 1
        img = Win32::Shortcut.open(img).path if $RUNNING_WINDOWS && File.extname(img) == ".lnk"
        date = File.basename(img, ".*").split("_")[0]
        parent_path = File.dirname(img)
        FileUtils.mkdir_p($stitched_images_path)
        unless File.exists? File.expand_path($stitched_images_path)
          puts "Failed to create output directory for stitched images. Please check read/write permissions on the output directory."
          return
        end
        begin
          system("#{$nona_path} -o #{date}_ #{%Q{"#{$master_alignment_file}"}} #{%Q{"#{parent_path}/#{date}_image1.jpg"}} #{%Q{"#{parent_path}/#{date}_image2.jpg"}} #{%Q{"#{parent_path}/#{date}_image3.jpg"}} #{%Q{"#{parent_path}/#{date}_image4.jpg"}}")
          system("#{$enblend_path} --no-optimize --compression=100 --fine-mask -o #{%Q{"#{$stitched_images_path}/#{date}_full.jpg"}} #{date}_0000.tif #{date}_0001.tif #{date}_0002.tif #{date}_0003.tif")
          Dir.glob("#{date}_*.tif").each { |f| File.delete(f) }
          match_count += 1
          completed_jobs += 1
        rescue
          # Ignore and move on
          # TODO:
          # Maybe do something in this case.
        end
      end
    end

    while completed_jobs != num_jobs
      # wait
    end

    puts "Stitching complete. Stitched #{match_count} out of #{count} possible frames."
    create_tm
  end

  def create_tm
    puts "Creating Time Machine..."
    $timemachine_output_dir = $create_videoset_segment_directory ? "#{$current_day}-#{$incremental_update_interval}m.timemachine" : "#{$current_day}.timemachine"
    # TODO: Assumes Ruby is installed and ct.rb is in the PATH
    system("ct.rb #{$working_dir} #{$timemachine_output_path}/#{$timemachine_output_dir} -j #{$num_jobs}")
    puts "Time Machine created."
    add_entry_to_json
    rsync_output_files if $rsync_output
    append_new_segments if $create_videoset_segment_directory
    completed_process
  end

  def add_entry_to_json
    json = {}
    path_to_json = "#{$working_dir}/#{$camera_location}.json"
    if File.exists?(path_to_json)
      json = open(path_to_json) {|fh| JSON.load(fh)}
    else
      json["location"] = $camera_location
      json["datasets"] = {}
    end
    new_latest = $current_day
    if json["latest"] and json["latest"]["date"]
      last_latest = json["latest"]["date"]
      last_latest_array = last_latest.split("-")
      date_array = $current_day.split("-")
      last_latest_year = last_latest_array[0].to_i
      last_latest_month = last_latest_array[1].to_i
      last_latest_day = last_latest_array[2].to_i
      date_year = date_array[0].to_i
      date_month = date_array[1].to_i
      date_day = date_array[2].to_i
      new_latest = last_latest if ((last_latest_year > date_year) or (last_latest_year >= date_year and last_latest_month > date_month) or (last_latest_year >= date_year and last_latest_month >= date_month and last_latest_day > date_day))
    else
      json["latest"] = {}
    end
    json["latest"]["date"] = new_latest
    json["latest"]["path"] = "http://g7.gigapan.org/timemachines/breathecam/#{$camera_location}/#{new_latest}.timemachine";
    json["datasets"]["#{$current_day}"] = "http://g7.gigapan.org/timemachines/breathecam/#{$camera_location}/#{$current_day}.timemachine"
    open(path_to_json, "w") {|fh| fh.puts(JSON.generate(json))}
    puts "Successfully wrote #{$camera_location}.json"
  end

  def append_new_segments
    # The code for appending is in a separate script, since it may potentially need to be run on another machine if the output files are there.
    # While we could rsync files in the above case, it would take too long once we get torwards the end of a day of images and we would be unable
    # to complete it in the 10 minutes (or less) window that we want. So, we just do all processing there.
    output_path = $output_path
    ssh_to_host_param = ""
    extra_ssh_command = ""
    if $rsync_output
      args = $output_path.split(":")
      host = args[0]
      output_path = args[1]
      extra_ssh_command = ". $HOME/.profile;"\
      # TODO
      # Appending script assumed to be in the same directory we ssh in. Also assumes ruby is installed and in the PATH.
      cmd = "ssh #{host} \"#{extra_ssh_command} ruby append_breathecam_videos.rb #{output_path}/#{$current_day}.timemachine #{output_path}/#{$timemachine_output_dir} #{$num_jobs}\""
    else
      # TODO
      # Appending script assumed to be in the same directory from which we called the script currently running. Also assumes ruby is installed and in the PATH.
      cmd = "ruby append_breathecam_videos.rb #{output_path}/#{$current_day}.timemachine #{$output_path}/#{$timemachine_output_dir} #{$num_jobs}"
    end
    system(cmd)
  end

  def rsync_output_files
    puts "Rsyncing #{$timemachine_output_path}/#{$timemachine_output_dir} to #{$output_path}"
    system("rsync -a #{$timemachine_output_path}/#{$timemachine_output_dir} #{$output_path}")
    unless $create_videoset_segment_directory
      puts "Rsyncing #{$camera_location}.json to #{$output_path}"
      system("rsync -a #{$working_dir}/#{$camera_location}.json #{$output_path}")
    end
  end

  def completed_process
    puts "Process Finished Successfully."
    puts "End Time: #{Time.now}"
  end

  def bash(command)
    escaped_command = Shellwords.escape(command)
    system("bash -c #{escaped_command}")
  end

  def usage
    puts "Usage: ruby create_breathe_cam_tm.rb PATH_TO_IMAGES OUTPUT_PATH_FOR_TIMEMACHINE PATH_TO_MASTER_HUGIN_ALIGNMENT_FILE CAMERA_SETUP_LOCATION"
    exit
  end

end

compiler = Compiler.new(ARGV)
