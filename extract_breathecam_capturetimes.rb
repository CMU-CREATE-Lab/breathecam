require "rexml/document"
require "date"
require "json"
require "time"

capture_times = []
dir = ARGV[0].dup
dir.chop! if dir[-1,1] == "/" || dir[-1,1] == "\\"
path = File.expand_path('*.jpg', dir)
files = Dir.glob(path).sort

files.each do |img_path|
 file = File.basename(img_path)
 date = file.split("_")[0].to_i
 capture_times << Time.at(date).to_datetime.strftime("%m/%d/%Y %I:%M %p")
end

json = open(ARGV[1]) {|fh| JSON.load(fh)}
json["capture-times"] = capture_times
open(ARGV[1], "w") {|fh| fh.puts(JSON.generate(json))}
STDERR.puts "Successfully wrote capture times to #{ARGV[1]}"
