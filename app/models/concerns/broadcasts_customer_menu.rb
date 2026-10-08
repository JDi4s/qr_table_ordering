module BroadcastsCustomerMenu
  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_customer_menu, on: [:create, :update, :destroy]
  end

  private

  def broadcast_customer_menu
    CustomerMenuBroadcast.call(establishment) if establishment
  end
end
