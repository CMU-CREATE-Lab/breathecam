class StaticController < ApplicationController

  def press
    respond_to do |format|
      format.html {render :layout => false}
    end
  end

end
