if ARGV.length < 1
  puts "Usage: ruby rotate_images.rb PATH_TO_IMAGES"                    
  return  
end  

do_in_place = false
rot_amt = 0
input_path = ""
 
unless input_path  
  puts "Invalid input path: #{input_path}"  
end  

while !ARGV.empty?
  arg = ARGV.shift
  if arg == "--in-place"
    do_in_place = true
  elsif arg == "--rot"
    rot_amt = ARGV.shift.to_i
  else
    input_path = arg
  end
end

input_path = input_path.tr('\\', "/").chomp("/")

if do_in_place
  `for img in #{input_path}/*.jpg ; do jpegtran -copy all -rotate #{rot_amt} -optimize -outfile $img $img;done 2>/dev/null`  
else  
  `for img in #{input_path}/*.jpg ; do jpegtran -copy all -rotate #{rot_amt} -optimize $img > ${img%.*}_rotated.jpg;done 2>/dev/null`                        
end  
