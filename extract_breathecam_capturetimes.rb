require "rexml/document"
require "date"
require "json"
require "time"

capture_times = []
dir = ARGV[0].dup

while !ARGV.empty?
  arg = ARGV.shift
  if arg == "-subsample-input"
    subsample_input = ARGV.shift.to_i
  elsif arg == "--print-seconds"
    print_seconds = true
  end
end

dir.chop! if dir[-1,1] == "/" || dir[-1,1] == "\\"
path = File.expand_path('*.jpg', dir)
files = Dir.glob(path).sort

files.each do |img_path|
 file = File.basename(img_path)
 date = file.split("_")[0].to_i
 extra = print_seconds ? ":%S" : ""
 capture_times << Time.at(date).to_datetime.strftime("%m/%d/%Y %I:%M#{extra} %p")
end

json = open(ARGV[1]) {|fh| JSON.load(fh)}
json["capture-times"] = capture_times
open(ARGV[1], "w") {|fh| fh.puts(JSON.generate(json))}
STDERR.puts "Successfully wrote capture times to #{ARGV[1]}"
