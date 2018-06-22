# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20180613134412) do

  create_table "camera_findings", :force => true do |t|
    t.string   "camera_id"
    t.string   "camera_name"
    t.text     "timemachine_path"
    t.text     "media_path"
    t.string   "media_format"
    t.integer  "media_width"
    t.integer  "media_height"
    t.text     "comment"
    t.datetime "begin_time"
    t.datetime "end_time"
    t.integer  "start_frame"
    t.integer  "num_frames"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  add_index "camera_findings", ["media_format"], :name => "index_camera_findings_on_media_format"

  create_table "camera_statuses", :force => true do |t|
    t.string   "camera_name"
    t.string   "camera_type"
    t.datetime "last_upload_time"
    t.datetime "last_image_time"
    t.datetime "last_ping"
  end

end
