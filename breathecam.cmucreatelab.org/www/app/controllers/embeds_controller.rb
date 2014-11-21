class EmbedsController < ApplicationController
  require "open-uri"
  require "date"

  layout 'embed'

  def index
    subdomain = request.subdomains(0).first
    @location_id = params['location']
    @root_url = "http://tiles.#{subdomain}.cmucreatelab.org"
    date_today = Date.today
    img_path = "#{@root_url}/images/#{@location_id}/050-original-images/#{date_today.to_s}/latest_stitch/"
    imageArray = []
    begin
      open(img_path) {|html|
        imageArray = html.read.scan(/\d*_full.jpg/).uniq.sort
      }
    rescue => e
      # Some error encountered. Most likely an invalid link.
    end

    # We might be checking at midnight and thus need to backtrack.
    # Or things might have really broken, so backtrack up to 3 weeks.
    # If we have not noticed a camera down in that timeframe, then shame on us.
    i = 1
    while i < 21 && imageArray.blank?
      img_path = img_path.gsub((date_today - (i - 1)).to_s,(date_today - i).to_s)
      begin
        open(img_path) {|html|
          imageArray = html.read.scan(/\d*_full.jpg/).uniq.sort
        }
      rescue => e
        # Some error encountered. Most likely an invalid link.
      end
      i += 1
    end

    @viewable_date = (date_today - i + 1).to_s

    # We did not find any stitched images for today or yesterday. There is most likely a problem with the image collection...
    if imageArray.blank?
      @stitched_image = ""
      respond_to do |format|
        format.html { render :file => "#{Rails.root}/public/404", :layout => false, :status => :not_found }
      end
      return
    end
    useTime = imageArray.first.scan(/^\d*/)[0].to_i
    @stitched_image = img_path + useTime.to_s + "_full" + ".jpg"
    @pretty_time = Time.at(useTime).to_datetime.strftime("%m/%d/%Y %I:%M %p")

    render :template => 'embeds/ecam' if subdomain == "ecam"
  end
end
