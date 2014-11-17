#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'parallel'

def append_and_cut(path_to_master_videoset, path_to_new_videoset)
  puts "[#{Time.now}] Cutting garbage frames from the beginning/end and then appending current set to master video files."
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
    end_frame_for_master = num_frames

    new_r_json = open(path_to_new_r_json) {|fh| JSON.load(fh)}
    additional_frame_count = new_r_json["frames"].to_i
    leader_for_next_segment = new_r_json["leader"].to_f
    start_time_for_next_segment = leader_for_next_segment.floor / fps

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
    add_leader = false
    if estimated_video_size < leader_threshold
      new_leader = 0
    else
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
        end_frame_for_master = actual_leader + num_frames
      else
        add_leader = true
      end
    end
    # END TODO

   Parallel.each_with_index(master_videos, :in_threads=> 8) do |video, index|
      next_segment_video = next_segment_videos[index]

      # Create a temp video file from the master that has the leader and black frames at the end removed.
      # We need double forward slashes for a links inside the .txt file below for things to work on Windows. Odd.
      tmp_master = "#{File.dirname(video)}/#{File.basename(video,'.*')}-cut.mp4".gsub('/','//')
      system("ffmpeg -y -i #{video} -vframes #{end_frame_for_master} -vcodec copy -acodec copy #{tmp_master}")

      # Create a temp video from the new file without a leader included but does still have black frames at the end.
      # We need double forward slashes for a links inside the txt file below for things to work on Windows. Odd.
      tmp_new_video = "#{File.dirname(next_segment_video)}/#{File.basename(next_segment_video,'.*')}-cut.mp4".gsub('/','//')

      if start_time_for_next_segment > 0.0
        system("ffmpeg -y -i #{next_segment_video} -ss #{start_time_for_next_segment} -vcodec copy -acodec copy #{tmp_new_video}")
      else
        tmp_new_video = next_segment_video
      end

      tmp_final_video = "#{File.dirname(video)}/#{File.basename(video,'.*')}-tmp.mp4"

      # If needed, we include the leader in the append below. This is only done once.
      leader_concat_command = add_leader ? "#{leader_path}.ts|" : ""

      # Append the leader (if needed), the master, and the next set of frames. We accomplish this by first doing an intermediate step of transcoding to mpeg transport streams and then concatenating. This makes use ffmpegs concat protocol.
      # Note: It seems that the demuxer protocol causes the fps of the final concatenated video to be incorrect (off by some %; i.e. 11.99 vs 12.0)
      system("ffmpeg -i #{tmp_master} -c copy -bsf:v h264_mp4toannexb -f mpegts #{tmp_master}.ts; ffmpeg -i #{tmp_new_video} -c copy -bsf:v h264_mp4toannexb -f mpegts #{tmp_new_video}.ts; ffmpeg -i 'concat:#{leader_concat_command}#{tmp_master}.ts|#{tmp_new_video}.ts' -c copy -bsf:a aac_adtstoasc #{tmp_final_video}")

      # Rename temp video to final video
      FileUtils.mv(tmp_final_video, video)

      # Remove the temp files
      File.delete(tmp_master)
      File.delete(tmp_master + ".ts")
    end

    # Update r.json with the new number of frames being added.
    master_r_json["frames"] = num_frames.to_i + additional_frame_count
    master_r_json["leader"] = new_leader
    open(path_to_master_r_json, "w") {|fh| fh.puts(JSON.pretty_generate(master_r_json))}

    # Update tm.json with capture times for the new frames being added.
    master_tm_json = open(path_to_master_tm_json) {|fh| JSON.load(fh)}
    new_tm_json = open(path_to_new_tm_json) {|fh| JSON.load(fh)}
    master_tm_json["capture-times"] += new_tm_json["capture-times"]
    open(path_to_master_tm_json, "w") {|fh| fh.puts(JSON.generate(master_tm_json))}

    # Update ajax_includes.js based on the new changes made to the json above.
    system("ruby #{path_to_ajax_includes_updater}")

    # Run qt-faststart. ffmpeg should be able to do this with '-movflags faststart' but apparently it does not actually do it. Perhaps because we are concatenating or copying streams?
    # TODO: We assume qtfaststart is in the PATH
    system("find #{path_to_master_videoset} -type f -name '*.mp4' -exec qtfaststart {} \\;")

    # Remove the new set since we just finished appending it to the master.
    FileUtils.rm_rf("#{path_to_new_videoset}")

    puts "[#{Time.now}] Finished appending new files."
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

append_and_cut(path_to_master_videoset, path_to_new_videoset)
