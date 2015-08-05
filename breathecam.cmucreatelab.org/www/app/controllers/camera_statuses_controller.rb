class CameraStatusesController < ApplicationController
  require 'fileutils'
  require "open-uri"

  def index
    Time.zone = "Eastern Time (US & Canada)"
    @camera_statuses = CameraStatus.order('camera_name').all
    @last_processed_times = []
    @camera_statuses.each do |cs|
      camera_name = cs.camera_name.split("_").last
      camera_type = cs.camera_type
      begin
        json1 = open("/usr0/web/timemachines/#{camera_type}/timemachines/#{camera_name}/#{camera_name}.json") {|fh| JSON.load(fh)}
        json2 = open(json1["latest"]["path"] + "/tm.json", :read_timeout => 5) {|fh| JSON.load(fh)}
        last_processed_time = @last_processed_time = json2["capture-times"].last
      rescue
        last_processed_time = "ERROR"
      end
      @last_processed_times << last_processed_time + " -0400"
    end
    respond_to do |format|
      format.html {render :layout => false}
    end
  end

end
