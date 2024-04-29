require 'fileutils'
require 'date'

src_root = ARGV[0]
dest_path = ARGV[1]
host = ARGV[2]
symlink_root = ARGV[3].empty? ? nil : ARGV[3]
finished_day = ARGV[4].empty? ? (Date.today - 1).to_s : ARGV[4]
remote_camera_source_paths = ARGV[5].empty? ? nil : ARGV[5].split(",")
local_camera_source_mnt = ARGV[6].empty? ? "" : ARGV[6]
log_file_path = ARGV[7].empty? ? nil : ARGV[7]
rsync_by_increment = ARGV[8]

if log_file_path
  $stdout.reopen(log_file_path, "a")
  $stdout.sync = true
  $stderr.reopen(log_file_path, "a")
  $stderr.sync = true
end

src_tm_path  = "#{src_root}/#{finished_day}.timemachine"
year_month_day = finished_day.split("-")
parent_output_path = symlink_root ? "#{dest_path}/#{year_month_day[0]}/#{year_month_day[1]}" : "#{dest_path}"
final_output_tm_path = "#{parent_output_path}/#{finished_day}.timemachine"
if rsync_by_increment
  tmp_output_tm_path = final_output_tm_path
else
  tmp_output_tm_path = final_output_tm_path + ".tmp"
end

puts "Running qtfaststart on tiles."
cmd = "find #{src_tm_path} -type f -name '*.mp4' -exec qtfaststart {} \\;"
system(cmd)
puts "Finished running qtfaststart."

puts "Rsyncing #{src_tm_path}/ to #{host}:/#{tmp_output_tm_path}"
cmd = "rsync -a --rsync-path='mkdir -p #{parent_output_path} && rsync' #{src_tm_path}/ #{host}:/#{tmp_output_tm_path}"
puts "#{cmd}"
is_success = system(cmd)
if !is_success
  puts "Error rsyncing."
  exit
end

cmd = "ssh #{host} "
extra_cmd = "\""
extra_cmd += "mv #{tmp_output_tm_path} #{final_output_tm_path};" unless rsync_by_increment
extra_cmd += "ln -s #{final_output_tm_path} #{symlink_root}/#{finished_day}.timemachine;" if symlink_root
extra_cmd += "\""
final_cmd = cmd + extra_cmd
puts "#{final_cmd}"
unless extra_cmd == "\"\""
  is_success = system(final_cmd)
  if !is_success
    puts "Error renaming and/or creating symlink on output server."
    exit
  end
end
puts "Finished rsyncing."

puts "Deleting local timemachine."
FileUtils.rm_rf(src_tm_path)
puts "Finished deleting local timemachine."

if remote_camera_source_paths
  puts "Deleting remote source images:"
  cmd = "ssh #{host} \""
  remote_camera_source_paths.each do |remote_camera_source_path|
    next if remote_camera_source_path.strip == "*"
    remote_camera_source_path.gsub!(local_camera_source_mnt, "")
    puts "  #{remote_camera_source_path}/#{finished_day}"
    cmd += "cd #{remote_camera_source_path}; rm -rf #{finished_day}; "
  end
  cmd += "\""
  puts "#{cmd}"
  is_success = system(cmd)
  if !is_success
    puts "Error deleting remote source images."
    exit
  end
  puts "Finished deleting remote source images."
end

puts "Done."
