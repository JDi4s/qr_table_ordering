class Staff::CategoriesController < ApplicationController
  layout "staff"
  before_action :require_login
  before_action :set_category, only: [:show, :edit, :update, :destroy, :toggle_availability]

  def index
    @categories = Category.order(:name)
  end

  def show; end
  def new; @category = Category.new; end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to staff_category_path(@category)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @category.update(category_params)
      redirect_to staff_category_path(@category)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to staff_categories_path
  end

  def toggle_availability
    @category.update!(available: !@category.available)
    redirect_to staff_categories_path, notice: "Availability updated"
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
end
