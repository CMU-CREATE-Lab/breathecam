class HomeController < ApplicationController
  require "open-uri"

  layout 'application'

  def index
    @img_path = "http://timemachine1.gc.cs.cmu.edu/timemachines/breathecam/heinz/050-original-images/"
    imageArray = []
    open(@img_path) {|html|
      imageArray = html.read.scan(/\d*_image\d.jpg/)
    }
    imageArray.uniq!
    lastTime = imageArray.last.scan(/^\d*/)[0].to_i
    useTime = lastTime
    count = imageArray.length - 1
    # Since we may be currently pulling images and thus not all images are present, always show the one before the current pull
    while (useTime == lastTime)
      count = count - 1
      useTime = imageArray[count].scan(/^\d*/)[0].to_i
      if useTime != lastTime
        break
      end
    end
    @img1 = useTime.to_s + "_image1"
    @img2 = useTime.to_s + "_image2"
    @img3 = useTime.to_s + "_image3"
    @img4 = useTime.to_s + "_image4"
    @pretty_time = Time.at(useTime).to_datetime.strftime("%m/%d/%Y %I:%M %p")
  end

end
