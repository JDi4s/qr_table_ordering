class Staff::MenuItemsController < ApplicationController
  layout "staff"
  before_action :require_login
  before_action :set_menu_item, only: [:show, :edit, :update, :destroy, :toggle_availability]

  def index
    @menu_items = MenuItem.includes(:category).order(:name)
  end

  def show; end
  def new; @menu_item = MenuItem.new; end

  def create
    @menu_item = MenuItem.new(menu_item_params)
    if @menu_item.save
      redirect_to staff_menu_item_path(@menu_item)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @menu_item.update(menu_item_params)
      redirect_to staff_menu_item_path(@menu_item)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_item.destroy
    redirect_to staff_menu_items_path
  end

  def toggle_availability
    @menu_item.update!(available: !@menu_item.available)
    redirect_to staff_menu_items_path, notice: "Availability updated"
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
end
