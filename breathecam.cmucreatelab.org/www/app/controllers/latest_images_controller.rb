class LatestImagesController < ApplicationController
  def index
    walnuttowers = ["nikonCamera19"]
    keith = ["nikonCamera2", "nikonCamera6"]
    golf_course = ["nikonCamera5", "nikonCamera3", "nikonCamera15"]
    dravosburg = ["nikonCamera14", "nikonCamera13"]
    dravosburg2 = ["nikonCamera17"]
    n_braddock = ["nikonCamera7", "nikonCamera10"]

    camera_collections = [walnuttowers, keith, golf_course, dravosburg, dravosburg2, n_braddock]
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

    # Eww, for multiple loops on the collection...
    current_camera_collection.each do |camera|
      @html += "<td>#{camera}</td>";
    end
    @html += "</tr><tr>";
    current_camera_collection.each do |camera|
      dates = Dir.glob("/usr3/timemachine_uploads/guest_uploader/#{camera}/050-original-images/*").select {|f| File.directory? f}.sort
      last_date = dates.last.split("/").last
      images_array = Dir.glob("/usr3/timemachine_uploads/guest_uploader/#{camera}/050-original-images/#{last_date}/*.jpg").sort
      images_array.each do |s|
        s.gsub!("/usr3/timemachine_uploads/guest_uploader/#{camera}/050-original-images/#{last_date}/", '')
      end
      @images << images_array
      latest_img = images_array.last
      @html += "<td><img style='cursor: pointer' onclick='window.open(this.src)' src='http://timemachine1.gc.cs.cmu.edu/timemachine_uploads/#{camera}/050-original-images/#{last_date}/#{latest_img}' width='640' height='480'></td>"
      latest_epoch_times << File.basename(latest_img, File.extname(latest_img))
    end
    @html += "</tr><tr>"
    latest_epoch_times.each_with_index do |epoch_time, idx|
      @html += "<td id='date-#{idx}'>" + Time.at(epoch_time.to_i).strftime('%b %d %Y %H:%M:%S') + "</td>"
    end

    @html += "</tr></table>"

    respond_to do |format|
      format.html {render :layout => false}
    end
  end
end
