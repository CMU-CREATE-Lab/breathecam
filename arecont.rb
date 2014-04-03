#!/usr/bin/env ruby2.0

require "open-uri"
require "date"
require "fileutils"

$host = ARGV[0] || "http://192.168.4.13"
$output_dir = ARGV[1] || "./"
$do_stitch = ARGV[2] || false

# Make sure only one instance of this script with a specific host is run
cmd = (`ps aux | grep "arecont.*#{$host} " | grep -v -E '(grep|sh|nano)'`)
num_instances = []

# Backwards compatibility with Ruby 1.8
if cmd.respond_to?(:lines) then
  num_instances = cmd.lines.to_a
else
  num_instances = cmd.to_a
end

if num_instances.length > 1
  exit()
end

$RUNNING_WINDOWS = /(win|w)32$/.match(RUBY_PLATFORM)
$RUNNING_MAC = RUBY_PLATFORM.downcase.include?("darwin")
$RUNNING_LINUX = RUBY_PLATFORM.downcase.include?("linux")

# For lossless image rotations
$jpegtran_path = $RUNNING_WINDOWS ? "jpegtran.exe" : "/usr/local/bin/jpegtran"

# Hugin tools
$nona_path = $RUNNING_WINDOWS ? "nona.exe" : "/usr/local/bin/nona"
$enblend_path = $RUNNING_WINDOWS ? "enblend.exe" : "/usr/local/bin/enblend"

$username = "admin"
$password = "illah123"
$config = "res=full&x0=0&y0=0&x1=3648&y1=2752&quality=21&doublescan=0"

loan_camera_lense_order = ["4","2","1","3"]
camera2_lense_order = ["1","4","2","3"]
camera3_lense_order = ["1","3","4","2"]
camera4_lense_order = ["1","3","4","2"]

$current_camera = camera3_lense_order

def get_images
  current_time = Time.now.to_i
  current_day = Date.today.to_s
  current_output_dir = File.join($output_dir,current_day)
  FileUtils.mkdir_p(current_output_dir)
  [1,2,3,4].each_with_index do |camera, i|
    File.open("#{current_output_dir}/#{current_time}_image#{$current_camera[i]}.jpg",'wb'){ |f| f.write(fetch("#{$host}/image#{camera}?#{$config}")) }
  end

  if $do_stitch
    latest_stitch_dir = "#{current_output_dir}/latest_stitch"
    FileUtils.mkdir_p(latest_stitch_dir)
    files = Dir.glob("#{current_output_dir}/#{current_time}_image*.jpg")
    exit if files.length != 4
    extra_param = $RUNNING_WINDOWS ? "" : ">"
    files.each do |img|
      return_value = system("#{$jpegtran_path} -copy all -rotate 180 -optimize #{%Q{"#{img}"}} #{extra_param} #{%Q{"#{latest_stitch_dir}/#{File.basename(img)}"}}")
      # Really we want to exit on any error, but the images from the arecont cameras have a malformed header, so jpegtran complains but continues. This triggers a return of false though.
      exit if return_value == nil
    end
    hugin_pto_file = "#{%Q{"#{File.expand_path(File.join(File.dirname(__FILE__), 'heinz2.pto'))}"}}"
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
    arecont_set(camera,'lowlight','highspeed'); # highspeed means honor shortexposures = exposure time
    arecont_set(camera,'maxdigitalgain',32);
    arecont_set(camera,'exposure','on');
    arecont_set(camera,'autoexp','on');
    arecont_set(camera,'analoggain', 1);
    arecont_set(camera,'shortexposures', 1);
  end
end

def set_breathecam_style
  [1, 2, 3, 4].each do |camera|
    defaults(camera)
    arecont_set(camera,'lowlight','moonlight'); # highspeed means honor shortexposures = exposure time
    arecont_set(camera,'brightness',5);
  end
end

def defaults(camera)
  arecont_set(camera,"analoggain", 25);
  arecont_set(camera,"maxdigitalgain", 96);
  arecont_set(camera,"brightness", 5);
  arecont_set(camera,"autoexp", "on");
  arecont_set(camera,"exposure", "on");
  arecont_set(camera,"equalbright", "on");
  arecont_set(camera,"equalcolor", "off");
  arecont_set(camera,"lowlight", "balance");
  arecont_set(camera,"shortexposures", 5);
  arecont_set(camera,"daynight", "auto");
end

def reload
  load __FILE__
end
