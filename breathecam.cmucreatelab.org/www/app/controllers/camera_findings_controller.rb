class CameraFindingsController < ApplicationController
  # GET /camera_findings
  # GET /camera_findings.json
  def index
    @camera_findings = CameraFinding.find(:all, :order => "begin_time")

    render :json => @camera_findings, :layout => false
  end

  # POST /camera_findings
  # POST /camera_findings.json
  def create
    @camera_finding = CameraFinding.new(params[:camera_finding])

    respond_to do |format|
      # Do not save unless the path to the thumbnail is a createlab domain
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
