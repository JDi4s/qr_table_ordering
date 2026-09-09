class Staff::CategoriesController < Staff::BaseController
  before_action :require_manager, except: :toggle_availability
  before_action :set_category, only: [:edit, :update, :destroy, :toggle_availability, :restore]
  before_action :load_parent_categories, only: [:new, :create, :edit, :update]

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

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to staff_menu_path, notice: 'Categoria atualizada.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.update!(archived_at: Time.current, available: false)
    redirect_to staff_menu_path, notice: 'Categoria arquivada.', status: :see_other
  end

  def restore
    @category.update!(archived_at: nil, available: true)
    redirect_to staff_menu_path, notice: 'Categoria restaurada.', status: :see_other
  end

  def toggle_availability
    raise Order::InvalidTransition, 'Restaure primeiro a categoria arquivada.' if @category.archived?

    @category.update!(available: !@category.available?)
    redirect_to staff_menu_path, status: :see_other
  end

  private

  def set_category
    @category = current_establishment.categories.find(params[:id])
  end

  def load_parent_categories
    @parent_categories = current_establishment.categories.not_archived.where.not(id: @category&.id).order(:name)
  end

  def category_params
    values = params.require(:category).permit(:name, :available, :parent_id)
    current_establishment.categories.not_archived.find(values[:parent_id]) if values[:parent_id].present?
    values
  end
end
