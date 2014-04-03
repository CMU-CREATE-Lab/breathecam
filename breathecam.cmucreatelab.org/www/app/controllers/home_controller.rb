class HomeController < ApplicationController
  require "open-uri"
  require "date"

  layout 'application'

  def index
    date_today = Date.today
    img_path = "http://timemachine1.gc.cs.cmu.edu/timemachines/breathecam/heinz/050-original-images/#{date_today.to_s}/latest_stitch/"
    imageArray = []
    begin
      open(img_path) {|html|
        imageArray = html.read.scan(/\d*_full.jpg/).uniq.sort
      }
    rescue => e
      # Some error encountered. Most likely an invalid link.
    end

    # We might be checking at midnight and thus need to backtrack
    if imageArray.blank?
      img_path = img_path.gsub(date_today.to_s,(date_today - 1).to_s)
      begin
        open(img_path) {|html|
          imageArray = html.read.scan(/\d*_full.jpg/).uniq.sort
        }
      rescue => e
        # Some error encountered. Most likely an invalid link.
      end
    end

    # We did not find any stitched images for today or yesterday. There is most likely a problem with the image collection...
    if imageArray.blank?
      @stitched_image = ""
      return
    end
    useTime = imageArray.first.scan(/^\d*/)[0].to_i
    @stitched_image = img_path + useTime.to_s + "_full" + ".jpg"
    @pretty_time = Time.at(useTime).to_datetime.strftime("%m/%d/%Y %I:%M %p")
  end
end
