#!/usr/bin/env ruby2.0

require "open-uri"
require "date"
require "fileutils"
require 'json'

$host = ARGV[0]
$output_path = ARGV[1] || "./"
$do_location_lookup = false
$location_id = $host
$location_lookup_path = "/usr4/web/breathecam.cmucreatelab.org/www/public/locations.json"
$do_latest_stitch = false
$skip_rotate_for_latest_stitch = false

$username = "admin"
$password = "illah123"
$config = "res=full&x0=0&y0=0&x1=3648&y1=2752&quality=21&doublescan=0"

$downtime_email = "pdille@andrew.cmu.edu"

# Broken Lense, Walnut Towers, Heinz, Trimont, Loaner
# The array index is the lense number going from left to right.
# The value at the array index is the output image number.
@@camera_list = [["4","2","1","3"], ["4","2","1","3"], ["1","3","4","2"], ["4","2","1","3"], ["4","2","1","3"]]

def usage
  puts "Usage: ruby arecont.rb HOST OUTPUT_PATH"
  exit
end

required_arg_count = 0
while !ARGV.empty?
  arg = ARGV.shift
  required_arg_count += 1
  if arg == "--do-latest-stitch"
    $do_latest_stitch = true
    required_arg_count -= 1
  elsif arg == "--do-location-lookup"
    $do_location_lookup = true
    required_arg_count -= 1
  elsif arg == "-camera-num"
    @@current_camera = @@camera_list[ARGV.shift.to_i - 1]
  elsif arg == "--skip-rotate-for-latest-stitch"
    $skip_rotate_for_latest_stitch = true
  end
end

if required_arg_count < 2
  usage
end

if $do_location_lookup && $location_id
  location_list  = open($location_lookup_path) {|f| f.read}
  if location_list && location_list[$location_id]
    location_list = JSON.parse(location_list)
    $host = location_list[$location_id]["ip"] + ":" + location_list[$location_id]["port"]
  end
end

instance_check = $location_id ? $location_id : $host

# Make sure only one instance of this script with a specific host is run
cmd = (`ps aux | grep 'arecont.*#{instance_check}.*"' | grep -v -E '(grep|sh|nano)'`)
num_instances = []

# Backwards compatibility with Ruby 1.8
if cmd.respond_to?(:lines) then
  num_instances = cmd.lines.to_a
else
  num_instances = cmd.to_a
end

if num_instances.length > 1
  puts "Already running: arecont.*#{instance_check}.*"
  exit()
end

# Make sure we add http:// in the event it is not included, since open() will fail without it
unless $host.include?("http://") || $host.include?("https://")
  $host = "http://" + $host
end

$RUNNING_WINDOWS = /(win|w)32$/.match(RUBY_PLATFORM)
$RUNNING_MAC = RUBY_PLATFORM.downcase.include?("darwin")
$RUNNING_LINUX = RUBY_PLATFORM.downcase.include?("linux")

# For lossless image rotations
$jpegtran_path = $RUNNING_WINDOWS ? "jpegtran.exe" : "/usr/local/bin/jpegtran"

# Hugin tools
$nona_path = $RUNNING_WINDOWS ? "nona.exe" : "/usr/local/bin/nona"
$enblend_path = $RUNNING_WINDOWS ? "enblend.exe" : "/usr/local/bin/enblend"

def get_images
  current_time = Time.now.to_i
  current_day = Date.today.to_s
  current_output_dir = File.join($output_path, current_day)
  FileUtils.mkdir_p(current_output_dir)
  downtime_logger = File.join(File.dirname(__FILE__), $location_id + ".downtime")
  puts "[#{Time.now}] Start pulling images from #{$location_id}"
  begin
    [1,2,3,4].each_with_index do |camera, i|
      puts "[#{Time.now}] Pulling image #{i + 1} from #{$location_id}"
      File.open("#{current_output_dir}/#{current_time}_image#{@@current_camera[i]}.jpg",'wb'){ |f| f.write(fetch("#{$host}/image#{camera}?#{$config}")) }
    end
    if File.exist?(downtime_logger)
      contents = File.open(downtime_logger, "r"){ |file| file.read }
      contents_array = contents.split(" ")
      count = contents_array.last.to_i
      system("mail -s '#{$location_id} breathecam back online [eom]' #{$downtime_email} < /dev/null") if (count > 1)
      File.delete(downtime_logger)
      # Camera settings were lost, so set them back to default breathecam settings
      set_breathecam_style
    end
    puts "[#{Time.now}] Completed pulling images from #{$location_id}"
  rescue
    count = 1
    if File.exist?(downtime_logger)
      new_down_time = Time.now.to_i
      contents = File.open(downtime_logger, "r"){ |file| file.read }
      contents_array = contents.split(" ")
      initial_down_time = contents_array.first.to_i
      count = contents_array.last.to_i
      time_diff = new_down_time - initial_down_time
      # Check every 10 min
      if (time_diff >= count * 600)
        time_down_in_minutes = (time_diff / 60).floor
        count = count + 1
        system("mail -s '#{$location_id} breathecam has been down for #{time_down_in_minutes} minutes [eom]' #{$downtime_email} < /dev/null")
      end
    else
      initial_down_time = new_down_time = Time.now.to_i
    end
    new_log_msg = initial_down_time.to_s + " " + new_down_time.to_s + " " + count.to_s
    File.open(downtime_logger, 'w') { |file| file.write(new_log_msg) }
    # Exit program
    exit
  end

  if $do_latest_stitch
    stitch_latest(current_time, current_output_dir)
  end
end

def fetch(url)
  open(url, :http_basic_authentication => [$username, $password]) {|x| x.read}
end

def print_settings
  [1,2,3,4].each do |camera|
    puts "Camera #{camera}:"
    ["analoggain", "maxdigitalgain", "brightness", "sharpness", "saturation", "illum", "autoexp", "exposure", "equalbright", "equalcolor", "lowlight", "shortexposures", "daynight"].each do |key|
      puts "  #{fetch("#{$host}/get#{camera}?#{key}")}"
    end
    puts "digitalgain: #{fetch("#{$host}/getreg?page=3&reg=209")}"
  end
  nil
end

def arecont_set(camera, key, value)
  puts fetch("#{$host}/set#{camera}?#{key}=#{value}")
end

def set_pulsefield_style
  [1].each do |camera|
    arecont_set(camera, 'lowlight', 'highspeed'); # highspeed means honor shortexposures = exposure time
    arecont_set(camera, 'maxdigitalgain', 32);
    arecont_set(camera, 'exposure', 'on');
    arecont_set(camera, 'autoexp', 'on');
    arecont_set(camera, 'analoggain', 1);
    arecont_set(camera, 'shortexposures', 1);
  end
end

def set_moonlight
  [1, 2, 3, 4].each do |camera|
    arecont_set(camera,'lowlight','moonlight'); # highspeed means honor shortexposures = exposure time
  end
end

def set_breathecam_style
  [1, 2, 3, 4].each do |camera|
    defaults(camera)
    arecont_set(camera, 'lowlight', 'moonlight'); # highspeed means honor shortexposures = exposure time
    arecont_set(camera, 'equalcolor', 'on');
    arecont_set(camera, 'brightness', 5);
  end
end

def defaults(camera)
  arecont_set(camera, "analoggain", 25);
  arecont_set(camera, "maxdigitalgain", 96);
  arecont_set(camera, "brightness", 5);
  arecont_set(camera, "autoexp", "on");
  arecont_set(camera, "exposure", "on");
  arecont_set(camera, "equalbright", "on");
  arecont_set(camera, "equalcolor", "off");
  arecont_set(camera, "lowlight", "balance");
  arecont_set(camera, "shortexposures", 5);
  arecont_set(camera, "daynight", "auto");
end

def stitch_latest(current_time, current_output_dir)
  latest_stitch_dir = "#{current_output_dir}/latest_stitch"
  FileUtils.mkdir_p(latest_stitch_dir)
  files = Dir.glob("#{current_output_dir}/#{current_time}_image*.jpg")
  exit if files.length != 4
  if !$skip_rotate_for_latest_stitch
    extra_param = $RUNNING_WINDOWS ? "" : ">"
    files.each do |img|
      return_value = system("#{$jpegtran_path} -copy all -rotate 180 -optimize #{%Q{"#{img}"}} #{extra_param} #{%Q{"#{latest_stitch_dir}/#{File.basename(img)}"}}")
      # Really we want to exit on any error, but the images from the arecont cameras have a malformed header, so jpegtran complains but continues. This triggers a return of false though.
      exit if return_value == nil
    end
  else
    files.each do |img|
      FileUtils.cp(img, latest_stitch_dir)
    end
  end
  hugin_pto_file = "#{%Q{"#{File.expand_path(File.join(File.dirname(__FILE__), $location_id + '.pto'))}"}}"
  Dir.chdir(latest_stitch_dir) do
    return_value = system("#{$nona_path} -o #{current_time}_ #{hugin_pto_file} #{current_time}_image1.jpg #{current_time}_image2.jpg #{current_time}_image3.jpg #{current_time}_image4.jpg")
    exit if !return_value
    return_value = system("#{$enblend_path} --no-optimize --compression=93 --fine-mask -o #{current_time}_full.jpg #{current_time}_0000.tif #{current_time}_0001.tif #{current_time}_0002.tif #{current_time}_0003.tif")
    exit if !return_value
    Dir["#{latest_stitch_dir}/*.*"].reject{ |f| f["#{current_time}_full.jpg"] }.each do |f|
      File.delete(f)
    end
  end
end

def reload
  load __FILE__
end
