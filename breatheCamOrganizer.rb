require 'fileutils'

$RUNNING_WINDOWS = /(win|w)32$/.match(RUBY_PLATFORM)
$RUNNING_MAC = RUBY_PLATFORM.downcase.include?("darwin")
$RUNNING_LINUX = RUBY_PLATFORM.downcase.include?("linux")
@verbose = false

if $RUNNING_WINDOWS
  require File.join(File.dirname(__FILE__), 'shortcut')
end

def main
  if ARGV.length != 2
    puts "Usage: ruby contat.rb PATH_TO_IMAGES OUTPUT_PATH"
    return
  end

  input_path = ARGV[0].tr('\\', "/").chomp("/")
  output_path = ARGV[1].tr('\\', "/").chomp("/")

  unless input_path
    puts "Invalid input path: #{input_path}"
  end

  unless output_path
    puts "Invalid output path: #{output_path}"
  end

  count = 0
  match_count = 0
  (Dir.glob("#{input_path}/*_image1.jpg")+Dir.glob("#{input_path}/*/*_image1.jpg")).sort.each do |img|
    count += 1
    date = File.basename(img, ".*").split("_")[0]
    unless File.exists?("#{input_path}/#{date}_image2.jpg") && File.exists?("#{input_path}/#{date}_image3.jpg") && File.exists?("#{input_path}/#{date}_image4.jpg")
      puts "Skipping #{date} since images were missing for it."
      next
    end
    path = File.expand_path(File.dirname(img))
    dir = "#{output_path}/0100-unstitched/#{'%05d' % count}"
    FileUtils.mkdir_p(dir)
    #logger.debug "Linking ..." if @verbose
    if $RUNNING_WINDOWS
      for i in 1..4
        Win32::Shortcut.new("#{dir}/#{date}_image#{i}" + ".lnk") do |s|
          s.path = "#{path}/#{date}_image#{i}.jpg" # Windows only supports absolute shortcut paths, in order to get them to be relative we need a special program: http://www.csparks.com/Relative/index.html
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
  puts "Matched #{match_count} out of #{count}"
end

main
