require "rexml/document"
require "json"
require "time"
require "date"
require "active_support"
require "active_support/core_ext"

capture_times = []
dir = ARGV[0].dup
time_diff = 0

print_seconds = true

path_to_tm_json = ARGV[1]

time_zone = "Eastern Time (US & Canada)"

while !ARGV.empty?
  arg = ARGV.shift
  if arg == "-subsample-input"
    subsample_input = ARGV.shift.to_i
  elsif arg == "--print-seconds"
    print_seconds = true
  elsif arg == "-capture-time-diff"
    time_diff = ARGV.shift.to_i
  elsif arg == "-time-zone"
    time_zone = ARGV.shift
  end
end

Time.zone = time_zone

dir.chop! if dir[-1,1] == "/" || dir[-1,1] == "\\"
path = File.expand_path('**/*.[jJpP][pPnN][gG]', dir)
files = Dir.glob(path).sort

files.each do |img_path|
 date = File.basename(img_path)
 capture_times << DateTime.parse(date).strftime("%Y-%m-%d %H:%M:%S") + " UTC"
end

json = open(path_to_tm_json) {|fh| JSON.load(fh)}
json["capture-times"] = capture_times
open(path_to_tm_json, "w") {|fh| fh.puts(JSON.generate(json))}
STDERR.puts "Successfully wrote capture times to #{path_to_tm_json}"
