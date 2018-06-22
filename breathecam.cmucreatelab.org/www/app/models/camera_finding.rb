class CameraFinding < ActiveRecord::Base

  attr_accessible :camera_name, :camera_id, :timemachine_path, :media_path, :media_format, :media_width, :media_height, :comment, :begin_time, :end_time, :start_frame, :num_frames, :created_at
  before_save :set_created_at

  def set_created_at
    self.created_at ||= Time.now
  end
end
