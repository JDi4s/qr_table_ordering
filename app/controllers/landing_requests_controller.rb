class LandingRequestsController < ApplicationController
  def create
    # This field is visually hidden. A filled value is a typical automated submission.
    if params[:website].present?
      redirect_to root_path(sent: 1), status: :see_other
      return
    end

    @landing_request = LandingRequest.new(request_params)
    if @landing_request.save
      redirect_to root_path(sent: 1, lang: params[:lang].presence, anchor: 'pedido'), status: :see_other
    else
      render 'landing/index', layout: false, status: :unprocessable_entity
    end
  end

  private

  def request_params
    params.require(:landing_request).permit(:first_name, :last_name, :business_email,
                                             :phone, :region, :business_type)
  end
end
