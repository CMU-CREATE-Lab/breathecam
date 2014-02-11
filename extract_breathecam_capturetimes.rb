require "rexml/document"
require "date"
require "json"
require "time"

capture_times = []
files = Dir.glob(File.join(ARGV[0], '*.jpg')).sort
files.each do |img_path|
 file = File.basename(img_path)
 date = file.split("_")[0].to_i
 capture_times << Time.at(date).to_datetime.strftime("%m/%d/%Y %I:%M %p")
end

json = open(ARGV[1]) {|fh| JSON.load(fh)}
json["capture-times"] = capture_times
open(ARGV[1], "w") {|fh| fh.puts(JSON.pretty_generate(json))}
