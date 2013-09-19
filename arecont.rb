#!/usr/bin/env ruby2.0

require "open-uri"

$host = "http://localhost:2324"

# http://localhost:2324/image3?res=full

# WTF
# Cameras for setting/getting values are 1 X X X
# Cameras for capturing are 3 2 4 1

def fetch(url)
  open(url) {|x| x.read}
end

def print_settings
  [1,2,3,4].each do |camera|
    puts "Camera #{camera}:"
    ["analoggain", "maxdigitalgain", "brightness", "sharpness", "saturation", "illum", "autoexp", "exposure", "equalbright", "equalcolor", "lowlight", "shortexposures", "daynight"].each do |key|
      puts "  #{fetch "#{$host}/get#{camera}?#{key}"}"
    end
    puts "digitalgain: #{fetch "#{$host}/getreg?page=3&reg=209"}"
  end
  nil
end

def arecont_set(camera, key, value)
  puts fetch "#{$host}/set#{camera}?#{key}=#{value}"
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

def set_breathcam_style
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


  
