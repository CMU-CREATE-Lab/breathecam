class AddLastPingToCameraStatuses < ActiveRecord::Migration
  def change
    add_column :camera_statuses, :last_ping, :datetime
  end
end
