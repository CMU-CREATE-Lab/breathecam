require 'rubygems'
require 'fileutils'

(Dir.glob("#{ARGV[0]}/*_image1.jpg")+Dir.glob("#{ARGV[0]}/*/*_image1.jpg")).each do |filename|
  date = File.basename(filename, ".*").split("_")[0]
  parent_path = File.dirname(filename)
  master_align = ARGV[1]
  output_path = ARGV[2] || parent_path
  FileUtils.mkdir_p(File.dirname(output_path))
  `nona -o temp #{master_align} #{parent_path}/#{date}_image1.jpg #{parent_path}/#{date}_image2.jpg #{parent_path}/#{date}_image3.jpg #{parent_path}/#{date}_image4.jpg`
  # --fine-mask seems to prevent an odd blending bug with enblend 4.2 from occuring on Linux.
  `enblend --compression=100 --fine-mask -o #{output_path}/#{date}_full.jpg temp0000.tif temp0001.tif temp0002.tif temp0003.tif`
end
