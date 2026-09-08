class Staff::CategoriesController < Staff::BaseController
  before_action :require_manager, except: :toggle_availability
  before_action :set_category, only: [:edit, :update, :destroy, :toggle_availability]
  def new
    @category = current_establishment.categories.new
  end
  def create
    @category = current_establishment.categories.new(category_params)
    if @category.save
      redirect_to staff_menu_path, notice: 'Categoria criada.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  def edit; end
  def update
    if @category.update(category_params)
      redirect_to staff_menu_path, notice: 'Categoria atualizada.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  def destroy
    @category.destroy!
    redirect_to staff_menu_path, status: :see_other
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to staff_menu_path, alert: 'A categoria tem produtos. Desative-a para preservar o histórico.'
  end
  def toggle_availability
    @category.update!(available: !@category.available?)
    redirect_to staff_menu_path, status: :see_other
  end
  private
  def set_category
    @category = current_establishment.categories.find(params[:id])
  end
  def category_params
    params.require(:category).permit(:name, :available)
  end
end
