#!/usr/bin/env ruby

require 'fileutils'
require 'json'

def add_entry_to_json(parent_path, root_tile_url, camera_location, current_day)
  path_to_json = "#{parent_path}/#{camera_location}.json"
  path_to_js = "#{parent_path}/#{camera_location}.js"

  if File.exists?(path_to_json)
    File.open(path_to_json).flock(File::LOCK_EX)
    File.open(path_to_js).flock(File::LOCK_EX)
    json = open(path_to_json) {|fh| JSON.load(fh)}
  else
    FileUtils.mkdir_p(parent_path) unless File.directory?(parent_path)
    json = {}
    json["location"] = $camera_location
    json["datasets"] = {}
  end

  new_latest = current_day
  if json["latest"] && json["latest"]["date"]
    last_latest = json["latest"]["date"]
    last_latest_array = last_latest.split("-")
    date_array = current_day.split("-")
    last_latest_year = last_latest_array[0].to_i
    last_latest_month = last_latest_array[1].to_i
    last_latest_day = last_latest_array[2].to_i
    date_year = date_array[0].to_i
    date_month = date_array[1].to_i
    date_day = date_array[2].to_i
    new_latest = last_latest if ((last_latest_year > date_year) || (last_latest_year >= date_year && last_latest_month > date_month) || (last_latest_year >= date_year && last_latest_month >= date_month && last_latest_day > date_day))
  else
    json["latest"] = {}
  end
  json["latest"]["date"] = new_latest
  json["latest"]["path"] = File.join(root_tile_url, camera_location, "#{new_latest}.timemachine")
  json["datasets"]["#{current_day}"] = File.join(root_tile_url, camera_location, "#{current_day}.timemachine")

  tmp_time = Time.now
  tmp_path_to_json = path_to_json + "_#{tmp_time}"
  tmp_path_to_js = path_to_js + "_#{tmp_time}"
  open(tmp_path_to_json, "w") {|fh| fh.puts(JSON.generate(json))}
  open(tmp_path_to_js, "w") {|fh| fh.puts("cached_breathecam=" + JSON.generate(json) + ";")}
  FileUtils.mv(tmp_path_to_json, path_to_json, :force => true)
  FileUtils.mv(tmp_path_to_js, path_to_js, :force => true)
  puts "Successfully wrote #{camera_location}.json"
  return true
rescue Exception => e
  puts e.message
  puts e.backtrace.inspect
ensure
  File.open(path_to_json).flock(File::LOCK_UN)
  File.open(path_to_js).flock(File::LOCK_UN)
end

add_entry_to_json(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
