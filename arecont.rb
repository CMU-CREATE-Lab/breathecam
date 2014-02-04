#!/usr/bin/env ruby2.0

require "open-uri"

# Make sure only one instance of this script runs
cmd = (`ps aux | grep arecont | grep -v -E '(grep|sh|nano)'`)
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

$host = ARGV[0] || "http://97.107.172.118"
$output_dir = ARGV[1] || "/usr0/web/timemachines/breathecam/heinz/050-original-images"

$username = "admin"
$password = "illah123"
$config = "res=full&x0=0&y0=0&x1=3648&y1=2752&quality=21&doublescan=0"

loan_camera_lense_order = ["4","2","1","3"]
camera3_lense_order = ["1","3","4","2"]

$current_camera = camera3_lense_order

def get_images
  current_time = Time.now.to_i
  [1,2,3,4].each_with_index do |camera, i|
    File.open("#{$output_dir}/#{current_time}_image#{$current_camera[i]}.jpg",'wb'){ |f| f.write(fetch("#{$host}/image#{camera}?#{$config}")) }
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
