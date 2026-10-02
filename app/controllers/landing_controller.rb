class LandingController < ApplicationController
  def index
    @landing_request = LandingRequest.new
    render layout: false
  end
end
