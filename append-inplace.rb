require 'parallel'
require 'json'
require 'fileutils'

path_to_master_videoset = ARGV[0]
path_to_new_videoset = ARGV[1]
suffix_only = ARGV[2]

if (path_to_master_videoset and path_to_new_videoset)
        puts "Append #{path_to_new_videoset} to #{path_to_master_videoset}"
	path_to_trailer = File.join(File.expand_path(File.dirname(__FILE__)), "suffix_10_600p.mp4")
	master_videos = Dir.glob("#{path_to_master_videoset}/crf*/*/*/*.mp4").sort

	if suffix_only
		puts "[#{Time.now}] Appending black frames to initial master set."
		Parallel.each_with_index(master_videos, :in_threads => 2) do |master_video, index|
			# Take master and append the black frame chunk to it. Also prepare the file for future frames.
			unless system("concatenate-mp4-videos.py #{master_video} #{path_to_trailer} --future_frames=17000")
				puts "[#{Time.now}] Error first time appending frames to master set."
				exit
			end
		end
	else
		puts "[#{Time.now}] Appending current set to master video files."

		path_to_master_r_json = Dir.glob("#{path_to_master_videoset}/crf*/r.json").first
		path_to_new_r_json = Dir.glob("#{path_to_new_videoset}/crf*/r.json").first
		path_to_master_tm_json = "#{path_to_master_videoset}/tm.json"
		path_to_new_tm_json = "#{path_to_new_videoset}/tm.json"
		path_to_ajax_includes = "#{path_to_master_videoset}/ajax_includes.js"
		path_to_ajax_includes_updater = "#{path_to_master_videoset}/update_ajax_includes.rb"

		master_r_json = open(path_to_master_r_json) {|fh| JSON.load(fh)}
		num_frames = master_r_json["frames"].to_f

		new_r_json = open(path_to_new_r_json) {|fh| JSON.load(fh)}
		additional_frame_count = new_r_json["frames"].to_i

		next_segment_videos = Dir.glob("#{path_to_new_videoset}/crf*/*/*/*.mp4").sort

		Parallel.each_with_index(master_videos, :in_threads => 2) do |master_video, index|
			next_segment_video = next_segment_videos[index]
			# Take master without the black frame chunk at the end, append the new segment, and then append the black frame chunk
			unless system("concatenate-mp4-videos.py '#{master_video}[0:-1]' #{next_segment_video} #{path_to_trailer}")
				puts "[#{Time.now}] Error appending additional frames to master set."
				exit
			end
		end

		tmp_time = Time.now

		# Update r.json with the new number of frames being added.
		master_r_json["frames"] = num_frames.to_i + additional_frame_count
		tmp_path_to_master_r_json = path_to_master_r_json + "_#{tmp_time}"
		open(tmp_path_to_master_r_json, "w") {|fh| fh.puts(JSON.pretty_generate(master_r_json))}
		FileUtils.mv(tmp_path_to_master_r_json, path_to_master_r_json, :force => true)

		# Update tm.json with capture times for the new frames being added.
		#master_tm_json = open(path_to_master_tm_json) {|fh| JSON.load(fh)}
		#new_tm_json = open(path_to_new_tm_json) {|fh| JSON.load(fh)}
		#master_tm_json["capture-times"] += new_tm_json["capture-times"] if new_tm_json["capture-times"]
		#tmp_path_to_master_tm_json = path_to_master_tm_json + "_#{tmp_time}"
		#open(tmp_path_to_master_tm_json, "w") {|fh| fh.puts(JSON.generate(master_tm_json))}
		#FileUtils.mv(tmp_path_to_master_tm_json, path_to_master_tm_json, :force => true)

		# Update ajax_includes.js based on the new changes made to the json above.
		system("ruby #{path_to_ajax_includes_updater}")

		# Remove the new set since we just finished appending it to the master.
		#FileUtils.rm_rf("#{path_to_new_videoset}")
	end

	# No qt-faststart required, since concatenate-mp4-videos.py already does the work and in fact, running qt-faststart
	# at this point removes the free buffer just added, which was there to speed up future appends.

	puts "[#{Time.now}] Finished inplace appending new files."

end
puts "Done"
