# Create a time machine from breathecam imagery

require 'fileutils'
require 'logger'

$RUNNING_WINDOWS = /(win|w)32$/.match(RUBY_PLATFORM)
$RUNNING_MAC = RUBY_PLATFORM.downcase.include?("darwin")
$RUNNING_LINUX = RUBY_PLATFORM.downcase.include?("linux")
$verbose = false
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO
# For lossless image rotations
$jpegtran_path = $RUNNING_WINDOWS ? "jpegtran.exe" : "jpegtran"
# Hugin tools
$nona_path = $RUNNING_WINDOWS ? "nona.exe" : "nona"
$enblend_path = $RUNNING_WINDOWS ? "enblend.exe" : "enblend"
$valid_image_extensions = [".jpg", ".lnk"]

if $RUNNING_WINDOWS
  require File.join(File.dirname(__FILE__), 'shortcut')
end

class Compiler
  def initialize(args)
    if args.length < 2
      usage
    end

    $input_path = ARGV[0]
    $output_path = ARGV[1]
    $master_alignment_file = ARGV[2]

    unless $input_path
      puts "Input path not provided."
      usage
    end

    unless $output_path
      puts "Output path not provided."
      usage
    end

    unless $output_path
      puts "Hugin alignment file not provided."
      usage
    end

    # Clean up paths if coming from Windows
    $input_path = $input_path.tr('\\', "/").chomp("/")
    $output_path = $output_path.tr('\\', "/").chomp("/")

    unless File.exists? File.expand_path($input_path)
      puts "Invalid input path: #{$input_path}"
    end

    organize_images
  end

  def organize_images
    $organized_images_path = File.join(File.dirname($input_path), "075-organized-raw-images")
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
    Dir.glob("#{$organized_images_path}/*/*.*").sort.each do |img|
      next unless $valid_image_extensions.include? File.extname(img).downcase
      count += 1
      img = Win32::Shortcut.open(img).path if $RUNNING_WINDOWS && File.extname(img) == ".lnk"
      begin
        system("#{$jpegtran_path} -copy all -rotate #{rot_amt} -optimize -outfile  #{%Q{"#{img}"}} #{%Q{"#{img}"}}")
        match_count += 1
      rescue

      end
    end
    puts "Rotating complete. Rotated #{match_count} out of #{count} images."

    stitch_images
  end

  def stitch_images
    count = 0
    match_count = 0
    puts "Stitching images..."
    $stitched_images_path = File.join(File.dirname($input_path), "0100-original-images")
    Dir.glob("#{$organized_images_path}/*/*_image1.*").sort.each do |img|
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
        system("#{$nona_path} -o temp #{%Q{"#{$master_alignment_file}"}} #{%Q{"#{parent_path}/#{date}_image1.jpg"}} #{%Q{"#{parent_path}/#{date}_image2.jpg"}} #{%Q{"#{parent_path}/#{date}_image3.jpg"}} #{%Q{"#{parent_path}/#{date}_image4.jpg"}}")
        system("#{$enblend_path} -o #{%Q{"#{$stitched_images_path}/#{date}_full.jpg"}} temp0000.tif temp0001.tif temp0002.tif temp0003.tif")
        match_count += 1
      rescue

      end
    end
    puts "Stitching complete. Stitched #{match_count} out of #{count} possible frames."
  end

  def usage
    puts "Usage: ruby contat.rb PATH_TO_IMAGES OUTPUT_PATH PATH_TO_MASTER_HUGIN_ALIGNMENT_FILE"
    return
  end

end

compiler = Compiler.new(ARGV)
