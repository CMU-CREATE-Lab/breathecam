require 'fileutils'
require 'date'

src_root = ARGV[0]
dest_path = ARGV[1]
host = ARGV[2]
symlink_root = ARGV[3]
previous_day = (Date.today - 1).to_s

src_tm_path  = "#{src_root}/#{previous_day}.timemachine"
year_month_day = previous_day.split("-")
final_output_tm_path = "#{dest_path}/#{year_month_day[0]}/#{year_month_day[1]}/#{previous_day}.timemachine"
tmp_output_tm_path = final_output_tm_path + ".tmp"

system("find #{src_tm_path} -type f -name '*.mp4' -exec qtfaststart {} \\;")
puts "Rsyncing #{src_tm_path}/ to #{host}:/#{tmp_output_tm_path}"
is_success = system("rsync -a #{src_tm_path}/ #{host}:/#{tmp_output_tm_path}")
if !is_success
  puts "Error rsyncing."
  exit
end
final_command = "ssh #{host} \"mv #{tmp_output_tm_path} #{final_output_tm_path}"
final_command += symlink_root ? "; ln -s #{final_output_tm_path} #{symlink_root}/#{previous_day}.timemachine\"" : "\""
is_success = system(final_command)
if !is_success
  puts "Error renaming and/or creating symlink on output server."
  exit
end
FileUtils.rm_rf(src_tm_path)
puts "Finished rsyncing."
