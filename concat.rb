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

  (Dir.glob("#{ARGV[0]}/*_image1.jpg")+Dir.glob("#{ARGV[0]}/*/*_image1.jpg")).each do |img|
    count += 1
    date = File.basename(img, ".*").split("_")[0]
    unless File.exists?("#{ARGV[0]}/#{date}_image2.jpg") && File.exists?("#{ARGV[0]}/#{date}_image3.jpg") && File.exists?("#{ARGV[0]}/#{date}_image4.jpg")
      next
    end
    path = File.dirname(img)
    `convert +append #{path}/#{date}_image1.jpg #{path}/#{date}_image2.jpg #{path}/#{date}_image3.jpg #{path}/#{date}_image4.jpg #{path}/#{date}_full.jpg`
    concat_count += 1
    puts "Concatenated image #{count}"
  end
  puts "Concatenated #{concat_count} images out of #{count}"
end

main
