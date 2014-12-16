#!/usr/bin/env ruby

# Create a time machine from breathecam imagery

require 'fileutils'
require 'date'
require 'time'
require 'json'
#require 'shellwords'
require 'parallel'

$RUNNING_WINDOWS = /(win|w)32$/.match(RUBY_PLATFORM)
$RUNNING_MAC = RUBY_PLATFORM.downcase.include?("darwin")
$RUNNING_LINUX = RUBY_PLATFORM.downcase.include?("linux")

# For lossless image rotations
$jpegtran_path = $RUNNING_WINDOWS ? "jpegtran.exe" : "jpegtran"

# Hugin tools
$nona_path = $RUNNING_WINDOWS ? "nona.exe" : "nona"
$enblend_path = $RUNNING_WINDOWS ? "enblend.exe" : "enblend"
$masker_path = "MaskedGaussian"

$valid_image_extensions = [".jpg", ".lnk"]
$default_num_jobs = 4
$rsync_input = false
$rsync_output = false
$rsync_location_json = false
$skip_rotate = false
$run_append_externally = false
$skip_stitch = false
$skip_leader = false
$input_date_from_file = false
$camera_type = "breathecam"
$skip_qtfaststart_append = false
$skip_videos = false
$apply_mask = false

if $RUNNING_WINDOWS
  require File.join(File.dirname(__FILE__), 'shortcut')
end

class Compiler
  def initialize(args)

    if args.length < 4
      usage
    end

    current_time = Time.now
    puts "Start Time: #{current_time}"

    $end_time = {}
    $end_time["full"] = current_time
    $end_time["hour"] = current_time.strftime("%H").to_i
    $end_time["minute"] = current_time.strftime("%M").to_i
    $end_time["sec"] = 0

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
      puts "Camera location name (e.g. heinz) not provided"
      usage
    end

    while !ARGV.empty?
      arg = ARGV.shift
      if arg == "-j"
        $num_jobs = ARGV.shift.to_i
      elsif arg == "--rsync-input"
        $rsync_input = true
      elsif arg == "--rsync-output"
        $rsync_output = true
      elsif arg == "--rsync-location-json"
        $rsync_location_json = true
      elsif arg == "-current-day"
        $current_day = ARGV.shift
      elsif arg == "-incremental-update-interval"
        # Force interval to be a multiple of 10.
        # This is needed because we add a keyframe every 10 frames
        # and thus do not need to worry about it when appending if we
        # keep it this way.
        $incremental_update_interval = (ARGV.shift.to_f / 10.0).ceil * 10
      elsif arg == "--skip-rotate"
        $skip_rotate = true
      elsif arg == "--run-append-externally"
        $run_append_externally = true
      elsif arg == "-ssd-mount"
        $ssd_mount = ARGV.shift
      elsif arg == "-working-dir"
        $working_dir = ARGV.shift
      elsif arg == "--skip-stitch"
        $skip_stitch = true
      elsif arg == "--skip-leader"
        $skip_leader = true
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
      end
    end

    # Clean up paths if coming from Windows
    $input_path = $input_path.tr('\\', "/").chomp("/")
    $output_path = $output_path.tr('\\', "/").chomp("/")

    if !$rsync_input && !File.exists?(File.expand_path($input_path))
      puts "Invalid input path: #{$input_path}"
      exit
    end

    # Specify where all 0XXX directories go. If the user does not pass in a custom path, then default to main output directory
    unless $working_dir
      if $rsync_output || $rsync_location_json
        $working_dir = File.join(File.dirname(__FILE__), "#{$camera_location}.tmc")
      else
        $working_dir = File.join($output_path, "#{$camera_location}.tmc")
      end
    end

    if File.exists?(File.join($working_dir, "WIP"))
      puts "[#{Time.now}] A file called 'WIP' was detected in '#{$working_dir}', which indicates that this working directory is already in the middle of processing. Aborting."
      exit
    end

    $timemachine_output_path = $rsync_output || $rsync_location_json ? $working_dir : $output_path

    $do_incremental_update = true if defined?($incremental_update_interval)

    if $current_day && $do_incremental_update
      puts "Specifying a day AND doing incremental appending is not supported. You can only do incremental appending from the actual day of running the script. \n So, either just specify a day OR specify incremental updating."
      exit
    end

    # If a date to process was not specified, then choose today if we are doing
    # incremental updates, otherwise do the previous day (since we have all images for that)
    $current_day ||= ($do_incremental_update ? Date.today.to_s : (Date.today - 1)).to_s

    $num_jobs ||= $default_num_jobs

    puts "Starting process."

    at_exit do
      FileUtils.rm(File.join($working_dir,"WIP"))
    end

    FileUtils.mkdir_p($working_dir)
    FileUtils.touch(File.join($working_dir,"WIP"))
    create_definition_file

    if $do_incremental_update
      if $input_date_from_file
        file = File.join($working_dir, "#{$camera_location}-last-pull-date.txt")
        if File.exists?(file)
          last_pull_date = Time.parse(File.open(file, &:readline))
          exit if (last_pull_date.to_i > Time.now.to_i)
          $start_time = {}
          $start_time["hour"] = last_pull_date.strftime("%H").to_i
          $start_time["minute"] = last_pull_date.strftime("%M").to_i
          $start_time["sec"] = 0
          $current_day = Date.parse(last_pull_date.to_s).to_s
          new_last_pull_date = last_pull_date + (60 * $incremental_update_interval)
          $end_time["hour"] = new_last_pull_date.strftime("%H").to_i
          $end_time["minute"] = new_last_pull_date.strftime("%M").to_i
          $end_time["sec"] = 0
          $end_time["full"] = new_last_pull_date
        else
          calculate_rsync_input_range
        end
        File.open(file, 'w') {|f| f.write($end_time["full"]) }
      else
        calculate_rsync_input_range
      end
    end
    clear_working_dir
    $rsync_input ? rsync_source_images : organize_images
  end

  def create_definition_file
    path_to_definition_file = "#{$working_dir}/definition.tmc"
    unless File.exists?(path_to_definition_file)
      FileUtils.cp("#{File.dirname(__FILE__)}/default_definition.tmc", path_to_definition_file)
      json = open(path_to_definition_file) {|fh| JSON.load(fh)}
      location_name = camera_name_remap($camera_location)
      json['id'] = location_name
      json['label'] = location_name
      open(path_to_definition_file, "w") {|fh| fh.puts(JSON.pretty_generate(json))}
    end
  end

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
        tmp_current_day = Date.parse($current_day)
        tmp_current_day -= day_diff
        tmp_current_day = tmp_current_day.strftime("%Y-%m-%d")
        # If we need to backtrack the day.
        if video_sets.last.include?(tmp_current_day)
          $current_day = tmp_current_day
          $start_time["hour"] = 24 - hour_diff
          $end_time["hour"] = 23
          $end_time["minute"] = 59
          $end_time["sec"] = 59
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
    puts "[#{Time.now}] Removing previous working files..."
    FileUtils.rm_rf("#{$working_dir}/050-raw-images")
    FileUtils.rm_rf("#{$working_dir}/075-organized-raw-images")
    FileUtils.rm_rf("#{$working_dir}/0100-original-images")
    # HAL cluster specific:
    # These directories are already set to symlinks with an ssd on HAL#,
    # so we just clear the old contents and start fresh.
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0200-tiles/*"))
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0300-tilestacks/*"))
    video_sets = Dir.glob("#{$timemachine_output_path}/*.timemachine").sort
    if $do_incremental_update and !video_sets.empty? and video_sets.last.include?($current_day)
      $create_videoset_segment_directory = true
    end
    puts "[#{Time.now}] Finished removing old files."
  end

  def rsync_source_images
    puts "[#{Time.now}] Rsycning images from #{$input_path}/#{$current_day}"
    image_path = $skip_stitch ? "0100-original-images" : "050-raw-images"
    new_input_path = File.join($working_dir, image_path)
    FileUtils.mkdir_p(new_input_path)

    if $do_incremental_update
      args = $input_path.split(":")
      host = args[0]
      src_path = args[1]
      puts "[#{Time.now}] ssh #{host} \"find #{src_path}/#{$current_day} -name '*.jpg' -newermt '#{$current_day} #{'%02d' % $start_time['hour']}:#{'%02d' % $start_time['minute']}:00' ! -newermt '#{$current_day} #{'%02d' % $end_time['hour']}:#{'%02d' % $end_time['minute']}:#{'%02d' % $end_time['sec']}' -printf '%f\n' > /tmp/#{$camera_location}-files.txt\""
      system("ssh #{host} \"find #{src_path}/#{$current_day} -name '*.jpg' -newermt '#{$current_day} #{'%02d' % $start_time['hour']}:#{'%02d' % $start_time['minute']}:00' ! -newermt '#{$current_day} #{'%02d' % $end_time['hour']}:#{'%02d' % $end_time['minute']}:#{'%02d' % $end_time['sec']}' -printf '%f\n' > /tmp/#{$camera_location}-files.txt\"")
      system("rsync -a --files-from=:/tmp/#{$camera_location}-files.txt #{$input_path}/#{$current_day}/ #{new_input_path}")
    else
      # Else grab the entire day of images
      system("rsync -a #{$input_path}/#{$current_day}/*.jpg #{new_input_path}")
    end

    # We need to reference files locally now that we have rsynced everything over
    $input_path = new_input_path
    puts "[#{Time.now}] Finished rsyncing input images."
    if $skip_stitch
      if Dir["#{$input_path}/*.jpg"].empty?
        puts "No images found to be processed. Aborting."
        if $do_incremental_update and $input_date_from_file
          file = File.join($working_dir, "#{$camera_location}-last-pull-date.txt")
          File.open(file, 'w') {|f| f.write(Time.now)}
        end
        exit
      end
      create_tm
    else
      organize_images
    end
  end

  def organize_images
    $organized_images_path = File.join($working_dir, "075-organized-raw-images")
    count = 0
    match_count = 0
    puts "[#{Time.now}] Organizing images..."
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
    puts "[#{Time.now}] Organizing complete. Matched #{match_count} out of #{count} possible frames."
    if $skip_rotate
      puts "Skipping image rotations."
      stitch_images
    else
      rotate_images
    end
  end

  def rotate_images
    rot_amt = 180
    count = 0
    match_count = 0
    puts "[#{Time.now}] Rotating images #{rot_amt} degrees clockwise..."
    files = Dir.glob("#{$organized_images_path}/*/*.*").sort
    Parallel.each(files, :in_threads => $num_jobs) do |img|
      next unless $valid_image_extensions.include? File.extname(img).downcase
      count += 1
      img = Win32::Shortcut.open(img).path if $RUNNING_WINDOWS && File.extname(img) == ".lnk"
      begin
        system("#{$jpegtran_path} -copy all -rotate #{rot_amt} -optimize -outfile  #{%Q{"#{img}"}} #{%Q{"#{img}"}}")
        match_count += 1
      rescue
        # Ignore and move on
        # TODO: Maybe do something in this case.
      end
    end
    puts "[#{Time.now}] Rotating complete. Rotated #{match_count} out of #{count} images."
    stitch_images
  end

  def stitch_images
    count = 0
    match_count = 0
    puts "[#{Time.now}] Stitching images..."
    stitched_images_path = File.join($working_dir, "0100-original-images")
    files = Dir.glob("#{$organized_images_path}/*/*_image1.*").sort
    Parallel.each(files, :in_threads => $num_jobs) do |img|
      next unless $valid_image_extensions.include? File.extname(img).downcase
      count += 1
      img = Win32::Shortcut.open(img).path if $RUNNING_WINDOWS && File.extname(img) == ".lnk"
      date = File.basename(img, ".*").split("_")[0]
      parent_path = File.dirname(img)
      FileUtils.mkdir_p(stitched_images_path)
      unless File.exists? File.expand_path(stitched_images_path)
        puts "Failed to create output directory for stitched images. Please check read/write permissions on the output directory."
        return
      end
      begin
        system("#{$nona_path} -o #{date}_ #{%Q{"#{$master_alignment_file}"}} #{%Q{"#{parent_path}/#{date}_image1.jpg"}} #{%Q{"#{parent_path}/#{date}_image2.jpg"}} #{%Q{"#{parent_path}/#{date}_image3.jpg"}} #{%Q{"#{parent_path}/#{date}_image4.jpg"}}")
        system("#{$enblend_path} --no-optimize --compression=100 --fine-mask -o #{%Q{"#{stitched_images_path}/#{date}_full.jpg"}} #{date}_0000.tif #{date}_0001.tif #{date}_0002.tif #{date}_0003.tif")
        Dir.glob("#{date}_*.tif").each { |f| File.delete(f) }
        match_count += 1
      rescue
        # Ignore and move on
        # TODO: Maybe do something in this case.
      end
    end
    puts "[#{Time.now}] Stitching complete. Stitched #{match_count} out of #{count} possible frames."
    $apply_mask ? apply_pano_mask : create_tm
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

  def create_tm
    puts "Creating Time Machine..."
    $timemachine_output_dir = $create_videoset_segment_directory ? "#{$current_day}-#{$incremental_update_interval}m.timemachine" : "#{$current_day}.timemachine"
    $timemachine_master_output_dir = "#{$current_day}.timemachine"
    extra_flags = ""
    extra_flags += "--skip-leader" if $skip_leader
    extra_flags += "--skip-videos --preserve-source-tiles" if $skip_videos
    # TODO: Assumes Ruby is installed and ct.rb is in the PATH
    Dir.chdir($working_dir) do
      system("ct.rb #{$working_dir} #{$timemachine_output_path}/#{$timemachine_output_dir} -j #{$num_jobs} #{extra_flags}")
    end
    puts "Time Machine created."
    add_entry_to_json
    rsync_output_files if $rsync_output && $run_append_externally
    append_new_segments if $create_videoset_segment_directory
    rsync_output_files($timemachine_master_output_dir) if $rsync_output && !$run_append_externally
    rsync_location_json if $rsync_location_json
    trim_ssd if $ssd_mount
    completed_process
  end

  def add_entry_to_json
    json = {}
    path_to_json = "#{$working_dir}/#{$camera_location}.json"
    path_to_js = "#{$working_dir}/#{$camera_location}.js"
    if File.exists?(path_to_json)
      json = open(path_to_json) {|fh| JSON.load(fh)}
    else
      json["location"] = $camera_location
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
    json["latest"]["date"] = new_latest
    json["latest"]["path"] = "http://tiles.cmucreatelab.org/#{$camera_type}/timemachines/#{$camera_location}/#{new_latest}.timemachine";
    json["datasets"]["#{$current_day}"] = "http://tiles.cmucreatelab.org/#{$camera_type}/timemachines/#{$camera_location}/#{$current_day}.timemachine"
    open(path_to_json, "w") {|fh| fh.puts(JSON.generate(json))}
    open(path_to_js, "w") {|fh| fh.puts("cached_breathecam=" + JSON.generate(json) + ";")}
    puts "Successfully wrote #{$camera_location}.json"
  end

  def append_new_segments
    # The code for appending is in a separate script, since it may potentially need to be run on another machine if the output files are there.
    # Rsync does allow us to send partial data and thus only the new segments would be sent, which we will take advantage of if we can, but if
    # we do not have rsync, at least the append script is separate and we have the choice to handle things outside this master script.
    output_path = $timemachine_output_path
    ssh_to_host_param = ""
    extra_ssh_command = ""
    if $rsync_output && $run_append_externally
      args = $output_path.split(":")
      host = args[0]
      output_path = args[1]
      extra_ssh_command = ". $HOME/.profile;"\
      # TODO: Appending script assumed to be in the same directory we ssh in. Also assumes ruby is installed and in the PATH.
      cmd = "ssh #{host} \"#{extra_ssh_command} ruby append_breathecam_videos.rb #{output_path}/#{$current_day}.timemachine #{output_path}/#{$timemachine_output_dir} #{$num_jobs}\""
      system(cmd)
    else
      # TODO: Appending script assumed to be in the same directory from which we called the script currently running. Also assumes ruby is installed and in the PATH.
      #cmd = "ruby #{File.join(File.dirname(__FILE__), 'append_breathecam_videos.rb')} #{output_path}/#{$timemachine_master_output_dir} #{output_path}/#{$timemachine_output_dir} #{$num_jobs}"
      append_and_cut("#{output_path}/#{$timemachine_master_output_dir}", "#{output_path}/#{$timemachine_output_dir}")
    end
  end

  def append_and_cut(path_to_master_videoset, path_to_new_videoset)
    FileUtils.touch(File.join($working_dir,"WIP2"))
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

      # TODO: We assume the leader is always 70 frames. It would be nice to actually calculate it
      # and create these frames on the fly, rather than use a pre-computed file.
      # It is faster this way, but we cannot always assume this fixed size, which is true
      # for a day of breathecam.
      leader_path = File.join(File.expand_path(File.dirname(__FILE__)), "leader_70.mp4")
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

      Parallel.each_with_index(master_videos, :in_threads => $num_jobs) do |video, index|
        next_segment_video = next_segment_videos[index]

        # Create a temp video file from the master that has the leader and black frames at the end removed.
        # We need double forward slashes for a links inside the .txt file below for things to work on Windows. Odd.
        tmp_master = "#{File.dirname(video)}/#{File.basename(video,'.*')}-cut.mp4".gsub('/','//')
        system("ffmpeg -y -i #{video} -vframes #{end_frame_for_master} -vcodec copy -acodec copy #{tmp_master}")

        # Create a temp video from the new file without a leader included but does still have black frames at the end.
        # We need double forward slashes for a links inside the txt file below for things to work on Windows. Odd.
        tmp_new_video = "#{File.dirname(next_segment_video)}/#{File.basename(next_segment_video,'.*')}-cut.mp4".gsub('/','//')

        if start_time_for_next_segment > 0.0
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

      # Update r.json with the new number of frames being added.
      master_r_json["frames"] = num_frames.to_i + additional_frame_count
      master_r_json["leader"] = new_leader
      open(path_to_master_r_json, "w") {|fh| fh.puts(JSON.pretty_generate(master_r_json))}

      # Update tm.json with capture times for the new frames being added.
      master_tm_json = open(path_to_master_tm_json) {|fh| JSON.load(fh)}
      new_tm_json = open(path_to_new_tm_json) {|fh| JSON.load(fh)}
      master_tm_json["capture-times"] += new_tm_json["capture-times"]
      open(path_to_master_tm_json, "w") {|fh| fh.puts(JSON.generate(master_tm_json))}

      # Update ajax_includes.js based on the new changes made to the json above.
      system("ruby #{path_to_ajax_includes_updater}")

      FileUtils.rm(File.join($working_dir,"WIP2"))

      # Run qt-faststart. ffmpeg should be able to do this with '-movflags faststart' but apparently it does not actually do it. Perhaps because we are concatenating or copying streams?
      # TODO: We assume qtfaststart is in the PATH
      # Once we go past 9pm, this process takes too long to fit in our 10 minute window. So, we skip it and will do it again once we rsync over the next day.
      unless $skip_qtfaststart_append
        curr_hour = Time.now.hour
        if curr_hour < 17 and (curr_hour != 0 or $current_day == Date.today.to_s)
          puts "[#{Time.now}] Running qt-faststart"
          system("find #{path_to_master_videoset}/crf*/0 -type f -name '*.mp4' -exec qtfaststart {} \\;")
          system("find #{path_to_master_videoset}/crf*/1 -type f -name '*.mp4' -exec qtfaststart {} \\;")
          system("find #{path_to_master_videoset}/crf*/2 -type f -name '*.mp4' -exec qtfaststart {} \\;")
          system("find #{path_to_master_videoset}/crf*/3 -type f -name '*.mp4' -exec qtfaststart {} \\;")
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

  def rsync_output_files(dir_to_rsync)
    dir_to_rsync ||= "#{$timemachine_output_dir}"
    puts "[#{Time.now}] Rsyncing #{$timemachine_output_path}/#{dir_to_rsync} to #{$output_path}"
    system("rsync -a #{$timemachine_output_path}/#{dir_to_rsync} #{$output_path}")
    rsync_location_json
  end

  def rsync_location_json
    unless $create_videoset_segment_directory
      puts "[#{Time.now}] Rsyncing #{$camera_location}.js{on} to #{$output_path}"
      system("rsync -a #{$working_dir}/#{$camera_location}.json #{$working_dir}/#{$camera_location}.js #{$output_path}")
    end
  end

  def trim_ssd
    puts "[#{Time.now}] Trimming #{$ssd_mount}"
    system("sudo fstrim -v #{$ssd_mount}")
  end

  def completed_process
    puts "[#{Time.now}] Process Finished Successfully."
    puts "End Time: #{Time.now}"
  end

  #def bash(command)
  #  escaped_command = Shellwords.escape(command)
  #  system("bash -c #{escaped_command}")
  #end

  def usage
    puts "Usage: ruby create_breathe_cam_tm.rb PATH_TO_IMAGES OUTPUT_PATH_FOR_TIMEMACHINE PATH_TO_MASTER_HUGIN_ALIGNMENT_FILE CAMERA_SETUP_LOCATION"
    exit
  end

end

compiler = Compiler.new(ARGV)
