def main
  if ARGV.length != 1
    puts "Usage: ruby contat.rb PATH_TO_IMAGES"
    return
  end

  unless File.directory?(ARGV[0])
    puts "Invalid input path: #{ARGV[0]}"
  end

  count = 0
  concat_count = 0

  (Dir.glob("#{ARGV[0]}/image1_*.jpg")+Dir.glob("#{ARGV[0]}/*/image1_*.jpg")).each do |img|
    count += 1
    date = File.basename(img, ".*").split("_")[1]
    unless File.exists?("#{ARGV[0]}/image2_#{date}.jpg") && File.exists?("#{ARGV[0]}/image3_#{date}.jpg") && File.exists?("#{ARGV[0]}/image4_#{date}.jpg")
      next
    end
    path = File.dirname(img)
    `convert +append #{path}/image1_#{date}.jpg #{path}/image2_#{date}.jpg #{path}/image3_#{date}.jpg #{path}/image4_#{date}.jpg #{path}/full_#{date}.jpg`
    concat_count += 1
    puts "Concatenated image #{count}"
  end
  puts "Concatenated #{concat_count} images out of #{count}"
end

main
