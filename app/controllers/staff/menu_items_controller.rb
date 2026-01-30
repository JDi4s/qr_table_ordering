class Staff::MenuItemsController < ApplicationController
  layout "staff"
  before_action :require_login
  before_action :set_menu_item, only: [:edit, :update, :destroy, :toggle_availability]

  def index
    redirect_to staff_menu_path
  end

  def show
    redirect_to staff_menu_path
  end

  def new
    @menu_item = MenuItem.new
  end

  def create
    @menu_item = MenuItem.new(menu_item_params)
    if @menu_item.save
      broadcast_menu!
      redirect_to staff_menu_path, notice: "Item created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @menu_item.update(menu_item_params)
      broadcast_menu!
      redirect_to staff_menu_path, notice: "Item updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_item.destroy
    broadcast_menu!
    redirect_to staff_menu_path, notice: "Item deleted"
  end

  def toggle_availability
    turning_on = !@menu_item.available

    if turning_on && !@menu_item.category.available
      redirect_to staff_menu_path, alert: "Turn ON the category first"
      return
    end

    @menu_item.update!(available: turning_on)
    broadcast_menu!
    redirect_to staff_menu_path, notice: "Availability updated"
  end

  private

  def set_menu_item
    @menu_item = MenuItem.find(params[:id])
  end

  def menu_item_params
    params.require(:menu_item).permit(:name, :price, :category_id, :available)
  end

  def require_login
    redirect_to login_path unless current_user&.staff?
  end

  def broadcast_menu!
    Turbo::StreamsChannel.broadcast_update_to(
      "menu",
      target: "customer_menu",
      partial: "orders/menu",
      locals: { categories: Category.includes(:menu_items).order(:name) }
    )
  end
end
