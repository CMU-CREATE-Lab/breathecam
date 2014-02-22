# Create a time machine from breathecam imagery

require 'fileutils'
require 'logger'
require 'date'
require 'json'
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
      puts "A file called 'WIP' was detected, which indicates that this working directory is already in the middle of processing."
      exit
    end

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
      end
    end

    $num_jobs ||= $default_num_jobs
    # TODO: Defaults to imagery from the prior day of when the script is called,
    # since there is currently a cron job that runs at midnight everynight.
    $current_day ||= (Date.today - 1).to_s

    # Clean up paths if coming from Windows
    $input_path = $input_path.tr('\\', "/").chomp("/")
    $output_path = $output_path.tr('\\', "/").chomp("/")

    if !$rsync_input && !File.exists?(File.expand_path($input_path))
      puts "Invalid input path: #{$input_path}"
      exit
    end

    puts "Starting process."

    $thread_pool = Pool.new($num_jobs)
    at_exit { $thread_pool.shutdown }

    FileUtils.mkdir_p($working_dir)
    FileUtils.touch(File.join($working_dir,"WIP"))
    clear_working_dir
    $rsync_input ? rsync_source_images : organize_images
  end

  # Mainly for Hal and its ssd setup
  def clear_working_dir
    puts "Removing previous working files..."
    FileUtils.rm_rf("#{$working_dir}/050-raw-images")
    FileUtils.rm_rf("#{$working_dir}/075-organized-raw-images")
    FileUtils.rm_rf("#{$working_dir}/0100-original-images")
    # These directories are already set to symlinks with the ssd on Hal,
    # so we just clear the old contents and start fresh.
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0200-tiles/*"))
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/0300-tilestacks/*"))
    FileUtils.rm_rf(Dir.glob("#{$working_dir}/*.timemachine"))
    puts "Finished removing old files."
  end

  def rsync_source_images
    puts "Rsycning images from #{$input_path}/#{$current_day}"
    new_input_path = File.join($working_dir, "050-raw-images")
    FileUtils.mkdir_p(new_input_path)
    system("rsync -a #{$input_path}/#{$current_day}/*.jpg #{new_input_path}")
    # We need to reference files locally now that we have rsynced everything over
    $input_path = new_input_path
    organize_images
    puts "Finished rsyncing input images."
  end

  def organize_images
    $organized_images_path = File.join($working_dir, "075-organized-raw-images")
    count = 0
    match_count = 0
    puts "Organizing images..."
    Dir.glob("#{$input_path}/*_image1.jpg").sort.each do |img|
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
    tmp_output_path = $rsync_output ? $working_dir : $output_path
    system("ct.rb #{$working_dir} #{tmp_output_path}/#{$current_day}.timemachine -j #{$num_jobs}")
    puts "Time Machine created."
    add_entry_to_json
    if $rsync_output
      rsync_output_files
    else
      completed_process
    end
  end

  def add_entry_to_json
    json = {}
    path_to_json = "#{$working_dir}/breathecam.json"
    if File.exists?(path_to_json)
      json = open(path_to_json) {|fh| JSON.load(fh)}
    else
      json["location"] = $camera_location
      json["datasets"] = {}
    end
    json["latest"] = {}
    json["latest"]["date"] = "#{$current_day}"
    json["latest"]["path"] = "http://g7.gigapan.org/timemachines/breathecam/#{$camera_location}/#{$current_day}.timemachine";
    json["datasets"]["#{$current_day}"] = "http://g7.gigapan.org/timemachines/breathecam/#{$camera_location}/#{$current_day}.timemachine"
    open(path_to_json, "wb") {|fh| fh.puts(JSON.generate(json))}
    puts "Successfully wrote breathecam.json"
  end

  def rsync_output_files
    puts "Rsyncing #{$current_day}.timemachine and breathecam.json to #{$output_path}"
    system("rsync -a #{$working_dir}/#{$current_day}.timemachine #{$output_path}")
    system("rsync -a #{$working_dir}/breathecam.json #{$output_path}")
    completed_process
  end

  def completed_process
    puts "Process Finished."
    FileUtils.rm(File.join($working_dir,"WIP"))
  end

  def usage
    puts "Usage: ruby create_breathe_cam_tm.rb PATH_TO_IMAGES OUTPUT_PATH_FOR_TIMEMACHINE PATH_TO_MASTER_HUGIN_ALIGNMENT_FILE CAMERA_SETUP_LOCATION"
    exit
  end

end

compiler = Compiler.new(ARGV)
