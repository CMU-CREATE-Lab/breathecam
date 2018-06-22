class AddIndexToMediaFormat < ActiveRecord::Migration
  def change
    add_index :camera_findings, :media_format
  end
end
