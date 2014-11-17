require 'fileutils'
require 'date'

src_root = ARGV[0]
dest_path = ARGV[1]
host = ARGV[2]
previous_day = (Date.today - 1).to_s

src_tm_path  = "#{src_root}/#{previous_day}.timemachine"
final_output_tm_path = "#{dest_path}/#{previous_day}.timemachine"
tmp_output_tm_path = final_output_tm_path + ".tmp"

system("find #{src_tm_path} -type f -name '*.mp4' -exec qtfaststart {} \\;")
puts "Rsyncing #{src_tm_path}/ to #{host}:/#{tmp_output_tm_path}"
system("rsync -a #{src_tm_path}/ #{host}:/#{tmp_output_tm_path}")
system("ssh #{host} \"mv #{tmp_output_tm_path} #{final_output_tm_path}\"")
FileUtils.rm_rf(src_tm_path)
puts "Finished rsyncing."
