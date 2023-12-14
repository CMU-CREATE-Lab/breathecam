require 'exiftool'
require 'time'

class LatestImagesController < ApplicationController
  # Pointing to public directory does not seem to work?
  # So, we point to a file system level symlink to where images are being stored.
  @@root_path = "/var/www/timemachine_uploads"
  #@@root_path = Rails.root.join("public", "timemachine_uploads")

  def index
    # TODO: Load this information from an external config
    #       Same with the name mapping that happens in camera_statuses/index.html.erb

    #walnuttowers = ["nikonCamera8"]
    keith = ["nikonCamera17", "nikonCamera13"]
    #golf_course = ["nikonCamera5", "nikonCamera3", "nikonCamera15"]
    #irvin = ["nikonCamera5"]
    #dravosburg = ["nikonCamera14", "nikonCamera13"]
    #dravosburg2 = ["nikonCamera17"]
    #n_braddock = ["nikonCamera7", "nikonCamera4"]
    #piquad3 = ["piquad3a", "piquad3b"]
    clairton3 = ["clairton3d", "clairton3c", "clairton3b", "clairton3a"]
    vanport1 = ["vanport1d", "vanport1c", "vanport1b", "vanport1a"]
    vanport2 = ["vanport2d", "vanport2c", "vanport2b", "vanport2a"]
    wmifflin1 = ["wmifflin1d", "wmifflin1c", "wmifflin1b", "wmifflin1a"]
    metalico1 = ["metalico1d", "metalico1c", "metalico1b", "metalico1a"]
    center1 = ["center1d", "center1c", "center1b", "center1a"]
    cryo1 = ["cryo2d", "cryo2c", "cryo2b", "cryo2a", "cryo1d", "cryo1c", "cryo1b", "cryo1a"]

    portrait_cams = [cryo1].flatten
    camera_collections = [keith, clairton3, vanport1, vanport2, wmifflin1, metalico1, center1, cryo1]

    current_camera_collection = []
    latest_epoch_times = []
    @images = []

    camera_collections.each do |camera_collection|
      if camera_collection.include?(params[:camera])
        current_camera_collection = camera_collection
        break
      end
    end

    current_camera_collection = [params[:camera]] if current_camera_collection.empty?

    @html = "<table><tr>";

    latest_imgs_exif_data = []
    # Eww, for multiple loops on the collection...
    current_camera_collection.each do |camera|
      @html += "<td>#{camera}</td>";
    end
    @html += "</tr><tr>";
    num_collections = current_camera_collection.length
    num_empty = 0
    current_camera_collection.each do |camera|
      dates = Dir.glob("#{@@root_path}/#{camera}/050-original-images/*").select {|f| File.directory? f}.sort
      if dates.empty?
        num_empty +=1
        if num_empty == num_collections
          respond_to do |format|
            format.html { render :text => "Sorry, no images found for this camera." }
          end
          return
        else
          next
        end
      end
      last_date = dates.last.split("/").last
      images_array = Dir.glob("#{@@root_path}/#{camera}/050-original-images/#{last_date}/*.jpg").sort
      images_array.each do |s|
        s.gsub!("#{@@root_path}/#{camera}/050-original-images/#{last_date}/", '')
      end
      @images << images_array
      latest_img = images_array.last
      latest_imgs_exif_data << Exiftool.new("#{@@root_path}/#{camera}/050-original-images/#{last_date}/#{latest_img}").to_hash
      img_class = "current-image"
      if portrait_cams.include?(camera)
        img_class += " portrait"
      end
      @html += "<td><img class='#{img_class}' onclick='window.open(this.src)' src='http://timemachine1.gc.cs.cmu.edu/timemachine_uploads/#{camera}/050-original-images/#{last_date}/#{latest_img}'></td>"
      latest_epoch_times << File.basename(latest_img, File.extname(latest_img))
    end
    @html += "</tr><tr>"
    latest_epoch_times.each_with_index do |epoch_time, idx|
      @html += "<td id='date-#{idx}'>" + Time.at(epoch_time.to_i).strftime('%b %d %Y %H:%M:%S') + "</td>"
    end

    @html += "</tr><tr>"

    latest_imgs_exif_data.each_with_index do |exif_data, idx|
      @html += "<td><table id='exifdata-#{idx}'>"
      @html += "<tr><td>Exposure Time: #{(exif_data[:exposure_time].to_f * 1000.0).round(2)} ms</td></tr>"
      @html += "<tr><td>ISO: #{exif_data[:iso]}</td></tr>"
      @html += "<tr><td>Aperture: #{exif_data[:aperture]}</td></tr>"
      @html += "</td></table>"
    end


    @html += "</tr></table>"

    respond_to do |format|
      format.html {render :layout => false}
    end
  end

  def get_exif()
    unless params[:url].nil?
      path = params[:url].gsub("http://timemachine1.gc.cs.cmu.edu/timemachine_uploads", @@root_path)
      exif_data = Exiftool.new(path).to_hash
      render :json => {"exposure_time" => (exif_data[:exposure_time].to_f * 1000.0).round(2), "iso" => exif_data[:iso], "aperture" => exif_data[:aperture]}
    end
    #respond_to do |format|
    # format.html { render :layout => false }
    #end
  end

  def camera_image_summaries()
    num_seconds_in_hour = 3600
    camera = params[:camera_id]

    if camera.blank?
      respond_to do |format|
        format.html { render :text => "Need to specify a camera id (camera_id=...)" }
      end
      return
    end

    last_date = params[:date]

    @hourly_counts = {}

    unless last_date
      dates = Dir.glob("#{@@root_path}/#{camera}/050-original-images/*").select {|f| File.directory? f}.sort
      if dates.empty?
        respond_to do |format|
          format.html { render :text => "Sorry, no images found for this camera." }
        end
        return
      end
      last_date = dates.last.split("/").last
    end

    images_array = Dir.glob("#{@@root_path}/#{camera}/050-original-images/#{last_date}/*.jpg").sort
    images_array.each do |s|
      date_str = File.basename(s, ".jpg")
      hour = (date_str.to_i / num_seconds_in_hour).floor * num_seconds_in_hour
      human_readable_hour = Time.at(hour).strftime("%Y-%m-%d at %I:%M%p")
      if (@hourly_counts[human_readable_hour])
        @hourly_counts[human_readable_hour] = @hourly_counts[human_readable_hour] += 1
      else
        @hourly_counts[human_readable_hour] = 1
      end
    end
    render :json => @hourly_counts
  end

end
