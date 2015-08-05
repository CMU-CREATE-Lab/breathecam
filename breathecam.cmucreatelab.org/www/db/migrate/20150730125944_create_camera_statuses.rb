class CreateCameraStatuses < ActiveRecord::Migration
  def self.up
    create_table :camera_statuses do |t|
      t.string :camera_name
      t.string :camera_type
      t.datetime :last_upload_time
      t.datetime :last_image_time
    end
  end

  def self.down
    drop_table :camera_statuses
  end
end
