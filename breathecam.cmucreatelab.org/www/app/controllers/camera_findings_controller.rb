class CameraFindingsController < ApplicationController
  ###skip_before_action :verify_authenticity_token

  # GET /camera_findings
  # GET /camera_findings.json
  def index
    begin_time_epoch = params[:begin_time]
    end_time_epoch = params[:end_time]
    camera_id = params[:camera_id]

    begin_time = begin_time_epoch ? Time.at(begin_time_epoch.to_i) : Time.at(0)
    end_time = end_time_epoch ? Time.at(end_time_epoch.to_i) : Time.now

    @camera_findings = CameraFinding.where("begin_time >= ? AND end_time <= ?", begin_time, end_time)
    @camera_findings = @camera_findings.where("camera_id = ?", camera_id) if camera_id
    @camera_findings = @camera_findings.order("begin_time")

    render :json => @camera_findings, :layout => false
  end

  # POST /camera_findings
  # POST /camera_findings.json
  def create
    @camera_finding = CameraFinding.new(params[:camera_finding])

    respond_to do |format|
      # Do not save unless the path to the thumbnail is a createlab domain
      # Adds some level of security to prevent arbitrary crap from being saved
      if @camera_finding.media_path.include?("createlab.org") and @camera_finding.save
        format.html { render text: "Success", status: 200 }
        format.json { render json: @camera_finding, status: :created }
      else
        format.html { render text: "Error", status: 422}
        format.json { render json: @camera_finding.errors, status: :unprocessable_entity }
      end
    end
  end
end
