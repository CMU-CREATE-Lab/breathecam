class CreateCameraFindings < ActiveRecord::Migration
  def self.up
    create_table :camera_findings do |t|
      t.string :camera_id
      t.string :camera_name
      t.text :timemachine_path
      t.text :media_path
      t.string :media_format
      t.integer :media_width
      t.integer :media_height
      t.text :comment
      t.datetime :begin_time
      t.datetime :end_time
      t.integer :start_frame
      t.integer :num_frames
      t.timestamps
    end
  end

  def self.down
    drop_table :camera_findings
  end
end
