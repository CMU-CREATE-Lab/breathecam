class CameraStatus < ActiveRecord::Base

  attr_accessible :last_upload_time, :last_image_time, :last_ping

end
