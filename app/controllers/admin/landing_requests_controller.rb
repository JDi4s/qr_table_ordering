class Admin::LandingRequestsController < Admin::BaseController
  before_action :set_request, only: [:show, :update]

  def index
    @status = LandingRequest::STATUSES.include?(params[:status]) ? params[:status] : 'new'
    @requests = LandingRequest.recent_first.where(status: @status).limit(200)
  end

  def show; end

  def update
    @request.update!(status: params.require(:landing_request).permit(:status).fetch(:status))
    redirect_to admin_landing_request_path(@request), notice: 'Estado do pedido atualizado.', status: :see_other
  end

  private

  def set_request
    @request = LandingRequest.find(params[:id])
  end
end
