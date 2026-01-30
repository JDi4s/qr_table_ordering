class Staff::CategoriesController < ApplicationController
  layout "staff"
  before_action :require_login
  before_action :set_category, only: [:edit, :update, :destroy, :toggle_availability]

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      broadcast_menu!
      redirect_to staff_menu_path, notice: "Category created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @category.update(category_params)
      broadcast_menu!
      redirect_to staff_menu_path, notice: "Category updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    broadcast_menu!
    redirect_to staff_menu_path, notice: "Category deleted"
  end

  # OFF => all items OFF
  # ON  => all items ON (still can toggle items individually afterwards)
  def toggle_availability
    new_value = !@category.available

    Category.transaction do
      @category.update!(available: new_value)
      @category.menu_items.update_all(available: new_value) # no callbacks
    end

    broadcast_menu!
    redirect_to staff_menu_path, notice: "Availability updated"
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :available)
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
