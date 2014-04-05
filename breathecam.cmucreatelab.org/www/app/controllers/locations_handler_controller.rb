class LocationsHandlerController < ApplicationController

  # We would need to pass a token back with each request,
  # but the arduino does not know this value, so we just skip this.
  protect_from_forgery :except => [:receive_data]

  def receive_data
    isValidRequest = false
    logOutputFile = ""
    locationsOutputFile = Rails.root.join('public', "locations.json")
    # Location lookup table. We check this when pulling images to get the correct IP.
    locations = File.file?(locationsOutputFile) ? open(locationsOutputFile) {|fh| JSON.load(fh)} : {}
    # What params we want in the location lookup table.
    logExcludeList = ["id", "uuid", "ip", "port"]
    logKeys = []

    bodyContent = request.body.read

    unless bodyContent.blank?
      paramsArray = bodyContent.split("&")
      locationName = ""
      logMsg = ""
      logMsg += Time.now.to_s
      paramsArray.each_with_index do |paramChunk, i|
        tmpParamArray = paramChunk.split("=")
        next if (tmpParamArray.length < 2)
        # Assumes the id (i.e. the location name) is the first param.
        if (i == 0)
          locationName = tmpParamArray[1]
          locations[locationName] = locations[locationName] || {}
          logOutputFile = Rails.root.join('public', "#{locationName}.log")
        else
          key = tmpParamArray[0]
          value = tmpParamArray[1]
          # Check that the request is valid. Of course someone
          # could have just snooped what a valid request looks like...
          if (key == "uuid")
            decodedId = view_context.hexToString(value)
            if (decodedId != locationName)
              logger.info "uuid error: " + value + " did not decode to " + locationName
            else
              isValidRequest = true
            end
          end
          if (logExcludeList.include?(key))
            locations[locationName][key] = value
          else
            logKeys << key
            logMsg += "\t" + value
          end
        end
      end

      locations[locationName]["ip"] = request.remote_ip.to_s

      if isValidRequest
        unless File.file?(logOutputFile)
          logHeader = "DATE \t"
          logKeys.each do |key|
            logHeader << key.upcase + "\t"
          end
          open(logOutputFile, "w") {|fh| fh.puts(logHeader)}
        end
        open(locationsOutputFile, "w") {|fh| fh.puts(JSON.generate(locations),"")}
        open(logOutputFile, "a") {|fh| fh.puts(logMsg)}
      end
    end

    respond_to do |format|
      format.all { head :ok, :content_type => 'text/html' }
    end
  end

end
