class Staff::MenuItemsController < ApplicationController
  before_action :require_login
  before_action :set_menu_item, only: [:show, :edit, :update, :destroy]

  def index
    @menu_items = MenuItem.includes(:category).joins(:category)
                         .order("categories.name ASC, menu_items.name ASC")
  end

  def show; end

  def new
    @menu_item = MenuItem.new
  end

  def create
    @menu_item = MenuItem.new(menu_item_params)
    if @menu_item.save
      redirect_to staff_menu_item_path(@menu_item), notice: "Menu item created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @menu_item.update(menu_item_params)
      redirect_to staff_menu_item_path(@menu_item), notice: "Menu item updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_item.destroy
    redirect_to staff_menu_items_path, notice: "Menu item deleted"
  end

  private

  def set_menu_item
    @menu_item = MenuItem.find(params[:id])
  end

  def menu_item_params
    params.require(:menu_item).permit(:name, :price, :category_id)
  end

  def require_login
    redirect_to login_path, alert: "Please log in as staff" unless current_user&.staff?
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end
