#!/usr/bin/env ruby

require 'json'
require 'shellwords'
require 'fileutils'
require File.join(File.expand_path(File.dirname(__FILE__)), 'thread-pool')

def append_and_cut(path_to_master_videoset, path_to_new_videoset)
  puts "Cutting garbage frames from the beginning/end and then appending current set to master video files."
  path_to_master_r_json = Dir.glob("#{path_to_master_videoset}/crf*/r.json").first
  path_to_new_r_json = Dir.glob("#{path_to_new_videoset}/crf*/r.json").first
  path_to_master_tm_json = "#{path_to_master_videoset}/tm.json"
  path_to_new_tm_json = "#{path_to_new_videoset}/tm.json"
  path_to_ajax_includes = "#{path_to_master_videoset}/ajax_includes.js"
  path_to_ajax_includes_updater = "#{path_to_master_videoset}/update_ajax_includes.rb"

  if File.exists?(path_to_master_r_json) and File.exists?(path_to_new_r_json) and File.exists?(path_to_ajax_includes) and File.exists?(path_to_ajax_includes_updater) and File.exists?(path_to_master_tm_json) and File.exists?(path_to_new_tm_json)
    master_r_json = open(path_to_master_r_json) {|fh| JSON.load(fh)}
    num_frames = master_r_json["frames"].to_f
    fps = master_r_json["fps"].to_f
    leader_for_master = master_r_json["leader"].to_f
    vid_width = master_r_json["video_width"].to_f
    vid_height = master_r_json["video_height"].to_f
    start_time = 0
    end_time_without_extra_end_frames = num_frames / fps

    new_r_json = open(path_to_new_r_json) {|fh| JSON.load(fh)}
    additional_frame_count = new_r_json["frames"].to_i
    leader_for_next_segment = new_r_json["leader"].to_f
    start_time_for_next_segment = leader_for_next_segment / fps

    master_videos = Dir.glob("#{path_to_master_videoset}/crf*/*/*/*.mp4").sort
    next_segment_videos = Dir.glob("#{path_to_new_videoset}/crf*/*/*/*.mp4").sort

    if master_videos.length != next_segment_videos.length
      puts "Different number of videos between sets. Aborting."
      return
    end

    # TODO
    # We assume the leader is always 70 frames. It would be nice to actually calculate it
    # and create these frames on the fly, rather than use a pre-computed file.
    # It is faster this way, but we cannot always assume this fixed size, which is true
    # for a day of breathecam.
    leader_path = File.join(File.expand_path(File.dirname(__FILE__)), "leader_70.mp4")
    leader_bytes_per_pixel={
      30 => 2701656.0 / (vid_width * vid_height * 90),
      28 => 2738868.0 / (vid_width * vid_height * 80),
      26 => 2676000.0 / (vid_width * vid_height * 70),
      24 => 2556606.0 / (vid_width * vid_height * 60)
    }
    bytes_per_frame = vid_width * vid_height * leader_bytes_per_pixel[26]
    leader_threshold = 1200000
    estimated_video_size = bytes_per_frame * num_frames
    if estimated_video_size < leader_threshold
      add_leader = false
      new_leader = 0
    else
      add_leader = true
      minimum_leader_length = 2500000
      leader_nframes = minimum_leader_length / bytes_per_frame
      # Round up to nearest multiple of frames per keyframe
      frames_per_keyframe = 10
      leader_nframes = (leader_nframes / frames_per_keyframe).ceil * frames_per_keyframe
      # The last two frames of the leader are actually dups of the first frames of the real video.
      # Since we are using a pre-computed leader video (that does not include this), we need to take this into account.
      # We subtract 1.9 (rather than 2) because browsers will show the leader if we go right up to the first frame of the video.
      # This value prevents the leader from showing and prevents the first of the last 10 black frames from peeking through. Sigh.
      new_leader = leader_nframes - 1.9
      actual_leader = leader_nframes - 2.0
      # The first time we add the leader we do not want to modify the start time, since
      # this assumes a leader is already present in the master video.
      if leader_for_master > 0
        start_time = actual_leader / fps
        end_time_without_extra_end_frames = (actual_leader + num_frames) / fps
      end
    end
    # END TODO

    num_jobs = master_videos.length
    completed_jobs = 0

    master_videos.each_with_index do |video, index|
      $thread_pool.schedule do
        next_segment_video = next_segment_videos[index]

        # Create a temp video file from the master that has the leader and black frames at the end removed.
        # We need double forward slashes for a links inside the .txt file below for things to work on Windows. Odd.
        tmp_master = "#{File.dirname(video)}/#{File.basename(video,'.*')}-cut.mp4".gsub('/','//')
        system("ffmpeg -y -i #{video} -ss #{start_time} -to #{end_time_without_extra_end_frames} -vcodec copy -acodec copy #{tmp_master}")
        # Create a temp video from the new file without a leader included but does still have black frames at the end.
        # We need double forward slashes for a links inside the txt file below for things to work on Windows. Odd.
        tmp_new_video = "#{File.dirname(next_segment_video)}/#{File.basename(next_segment_video,'.*')}-cut.mp4".gsub('/','//')
        system("ffmpeg -y -i #{next_segment_video} -ss #{start_time_for_next_segment} -vcodec copy -acodec copy #{tmp_new_video}")

        # Append the leader (if needed), tmp_master and tmp_new_video together and overwrite the original master.
        # Bash shell specifics (command substitution) left here for a reminder of how convenient it is...but alas not portable.
        video_append_list = ""
        #video_append_list += "<(printf \""
        video_append_list += "file '#{leader_path}'\r\n" if add_leader
        video_append_list += "file '#{tmp_master}'\r\n"
        video_append_list += "file '#{tmp_new_video}'"
        #video_append_list += "\")"

        video_append_list_output = "#{File.dirname(video)}/#{File.basename(video,'.*')}-append-list.txt"
        File.open(video_append_list_output, 'w') {|f| f.write(video_append_list) }

        tmp_final_video = "#{File.dirname(video)}/#{File.basename(video,'.*')}-tmp.mp4"
        # Change to bash() if we want to make use of the Bash shell stuff commented out above.
        system("ffmpeg -y -f concat -i #{video_append_list_output} -movflags faststart -vcodec copy -acodec copy #{tmp_final_video}")
        File.delete("#{video}")
        File.rename(tmp_final_video, "#{video}")

        # Remove the temp files
        File.delete(tmp_master)
        File.delete(tmp_new_video)
        File.delete(video_append_list_output)
        completed_jobs += 1
      end
    end

    while completed_jobs != num_jobs
      # wait
    end

    # Update r.json with the new number of frames being added.
    master_r_json["frames"] = num_frames.to_i + additional_frame_count
    master_r_json["leader"] = new_leader
    open(path_to_master_r_json, "w") {|fh| fh.puts(JSON.pretty_generate(master_r_json))}

    # Update tm.json with capture times for the new frames being added.
    master_tm_json = open(path_to_master_tm_json) {|fh| JSON.load(fh)}
    new_tm_json = open(path_to_new_tm_json) {|fh| JSON.load(fh)}
    master_tm_json["capture-times"] += new_tm_json["capture-times"]
    open(path_to_master_tm_json, "w") {|fh| fh.puts(JSON.pretty_generate(master_tm_json))}

    # Update ajax_includes.js based on the new changes made to the json above.
    system("ruby #{path_to_ajax_includes_updater}")

    # Remove the new set since we just finished appending it to the master.
    FileUtils.rm_rf("#{path_to_new_videoset}")

    puts "Finished appending new files."
  else
    if !File.exists?(path_to_master_r_json)
      puts "Did not find r.json for the master videoset."
    elsif !File.exists?(path_to_new_r_json)
      puts "Did not find r.json for the new videoset."
    elsif !File.exists?(path_to_ajax_includes)
      puts "Did not find ajax_includes.js for the master videoset"
    elsif !File.exists?(path_to_ajax_includes_updater)
      puts "Did not find update_ajax_includes.rb for the master videoset."
    elsif !File.exists?(path_to_master_tm_json)
      puts "Did not find tm.json for the master videoset."
    elsif !File.exists?(path_to_new_tm_json)
      puts "Did not find tm.json for the new videoset."
    end
  end
end

def bash(command)
  escaped_command = Shellwords.escape(command)
  system("bash -c #{escaped_command}")
end

$thread_pool = nil

if ARGV.length < 2
  puts "usage: append_breathecam_videos.rb PATH_TO_MASTER_VIDEOSET PATH_TO_NEW_VIDEOSET"
  exit
end

path_to_master_videoset = ARGV[0]
path_to_new_videoset = ARGV[1]
num_jobs = ARGV[2]

num_jobs ||= 4

if !File.exists?(path_to_master_videoset)
  puts "Invalid path to master videoset"
  exit
elsif !File.exists?(path_to_new_videoset)
  puts "Invalid path to new videoset"
  exit
end

$thread_pool = Pool.new(num_jobs.to_i)
at_exit { $thread_pool.shutdown }

append_and_cut(path_to_master_videoset, path_to_new_videoset)
