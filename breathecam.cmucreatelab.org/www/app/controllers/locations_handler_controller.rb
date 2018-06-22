class LocationsHandlerController < ApplicationController
  require 'date'
  require 'fileutils'
  # We would need to pass a token back with each request,
  # but the arduino does not know this value, so we just skip this.
  protect_from_forgery :except => [:receive_data, :upload]

  def upload
    if params[:id]
      upload_time = DateTime.now
      num_images = params[:images].length
      time_offset_in_seconds = 0
      params[:images].each_with_index do |image, index|
        begin
          # The time param is legacy, and in theory should be used for the timestamp,
          # but I do not think it was ever a reliable time to use. So, we force an
          # exif lookup if we encounter requests with that param.
          if params[:useEXIF] == "true" || params[:time]
            s = `/usr/bin/exiftool -time:CreateDate #{image.path}`
            a = s.split(": ")
            a[1] = a[1].chomp
            a2 = a[1].split(" ")
            a2[0].gsub!(":", "-")
            final = a2[0] + " " + a2[1]
            time_obj = Time.parse(final)
          else
            tmp_t = File.basename(image.original_filename, ".*").split("_")[0].to_i
            time_obj = Time.at(tmp_t.to_i)
          end
        rescue
          respond_to do |format|
            format.json { render json: { "success" => true } }
            format.all { head :ok, :content_type => 'application/json' }
          end
          return
        end

        ### BEGIN TIME CORRECTIONS ###
        if params[:id] == "a7s_shenango2"
          # 31535957 = (1 year - 45 seconds)
          # 31532402 = (1 year - 1 hr)
          # 31536002 = (1 year + 1 hr)
          time_offset_in_seconds = 31536002
        elsif params[:id] == "a7s_shenango1"
          # 3600 = (1 hr)
          time_offset_in_seconds = -3600
        end
        ### END TIME CORRECTIONS ###

        time_obj += time_offset_in_seconds
        time_in_seconds = time_obj.to_i
        current_date = time_obj.to_s.split(" ")[0]
        name = time_in_seconds.to_s + File.extname(image.original_filename)
        camera_status = CameraStatus.find_or_create_by_camera_name(params[:id].split("_").last) do |cs|
          cs.camera_type = 'ecam'
        end
        camera_status.update_attributes(:last_upload_time => upload_time, :last_image_time => time_obj)
        directory = File.join(Rails.public_path, "upload", params[:id], "050-original-images", current_date)
        FileUtils.mkdir_p(directory)
        path = File.join(directory, name)
        File.open(path, "wb") { |f| f.write(image.read) }
        #if index == num_images - 1
        #  latest_stitch_directory = File.join(directory, "latest_stitch")
        #  FileUtils.mkdir_p(latest_stitch_directory)
        #  FileUtils.rm_rf(Dir.glob("#{latest_stitch_directory}/*"))
        #  latest_stitch_path = File.join(latest_stitch_directory, File.basename(name, File.extname(name)).chomp("_image") + "_full" + File.extname(name))
        #  FileUtils.cp(path, latest_stitch_path)
        #end
      end
      respond_to do |format|
        format.json { render json: { "success" => true } }
        format.all { head :ok, :content_type => 'application/json' }
      end
    else
      respond_to do |format|
        format.json { render json: { "success" => false } }
        format.all { head :internal_server_error, :content_type => 'application/json' }
      end
    end
  end

  def receive_data
    isValidRequest = false
    ##logOutputFile = ""
    locationsOutputFile = Rails.root.join('public', "locations.json")
    # Location lookup table. We check this when pulling images to get the correct IP.
    locations = File.file?(locationsOutputFile) ? open(locationsOutputFile) {|fh| JSON.load(fh)} : {}
    # What params we want in the location lookup table.
    logExcludeList = ["id", "uuid", "ip", "port"]
    ##logKeys = []

    bodyContent = request.body.read

    unless bodyContent.blank?
      paramsArray = bodyContent.split("&")
      locationName = ""
      logMsg = ""
      logMsg += Time.now.to_s
      paramsArray.each_with_index do |paramChunk, i|
        tmpParamArray = paramChunk.split("=")
        next if (tmpParamArray.length < 2)
        # Assumes the id (i.e. the location name) is the first param.
        if (i == 0)
          locationName = tmpParamArray[1]
          locations[locationName] = locations[locationName] || {}
          ##logOutputFile = Rails.root.join('public', "#{locationName}.log")
        else
          key = tmpParamArray[0]
          value = tmpParamArray[1]
          # Check that the request is valid. Of course someone
          # could have just snooped what a valid request looks like...
          if (key == "uuid")
            decodedId = view_context.hexToString(value)
            if (decodedId != locationName)
              logger.info "uuid error: " + value + " did not decode to " + locationName
            else
              isValidRequest = true
            end
          end
          if (logExcludeList.include?(key))
            locations[locationName][key] = value
          ##else
          ##  logKeys << key
          ##  logMsg += "\t" + value
          end
        end
      end

      locations[locationName]["ip"] = request.remote_ip.to_s

      if isValidRequest
        ##unless File.file?(logOutputFile)
        ##  logHeader = "DATE \t"
        ##  logKeys.each do |key|
        ##    logHeader << key.upcase + "\t"
        ##  end
        ##  open(logOutputFile, "w") {|fh| fh.puts(logHeader)}
        ##end
        camera_status = CameraStatus.find_or_create_by_camera_name(locationName.split("_").last) do |cs|
          cs.camera_type = 'ecam'
        end
        camera_status.update_attributes(:last_ping => DateTime.now)
        open(locationsOutputFile, "w") {|fh| fh.puts(JSON.generate(locations),"")}
        ##open(logOutputFile, "a") {|fh| fh.puts(logMsg)}
      end
    end

    respond_to do |format|
      format.all { head :ok, :content_type => 'text/html' }
    end
  end
end
