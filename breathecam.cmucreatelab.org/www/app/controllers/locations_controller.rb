class LocationsController < ApplicationController
  layout 'application'

  def index
    @location_id = params['location']
  end
end
