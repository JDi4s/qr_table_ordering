class Staff::CategoriesController < Staff::BaseController
  rescue_from Order::InvalidTransition, with: :invalid_menu_operation
  before_action :require_manager, except: :toggle_availability
  before_action :set_category, only: [:edit, :update, :destroy, :toggle_availability, :restore, :purge]
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
    redirect_to menu_destination(@category.id), notice: 'Categoria arquivada.', status: :see_other
  end

  def restore
    @category.update!(archived_at: nil, available: true)
    redirect_to menu_destination(@category.id), notice: 'Categoria restaurada.', status: :see_other
  end

  def purge
    raise Order::InvalidTransition, 'A categoria “Sem categoria” é necessária para guardar produtos sem categoria.' if @category.uncategorized?
    moved_products = @category.menu_items.count
    moved_children = @category.children.count
    metadata = { deleted_category_id: @category.id, name: @category.name,
                 moved_products: moved_products, moved_subcategories: moved_children }

    Category.transaction do
      destination = uncategorized_category! if moved_products.positive?
      @category.children.update_all(parent_id: @category.parent_id, updated_at: Time.current) if moved_children.positive?
      @category.menu_items.update_all(category_id: destination.id, updated_at: Time.current) if moved_products.positive?
      @category.destroy!
      AuditLogger.record(user: current_user, action: 'category_deleted', metadata: metadata)
    end

    message = if moved_products.positive?
      "Categoria eliminada. #{moved_products} #{moved_products == 1 ? 'produto foi movido' : 'produtos foram movidos'} para “Sem categoria”."
    else
      'Categoria eliminada.'
    end
    redirect_to menu_destination, notice: message, status: :see_other
  end

  def toggle_availability
    raise Order::InvalidTransition, 'Restaure primeiro a categoria arquivada.' if @category.archived?

    @category.update!(available: !@category.available?)
    redirect_to menu_destination(@category.id), status: :see_other
  end

  private

  def menu_destination(category_id = nil)
    staff_menu_path(menu_status: menu_status, open_category_id: category_id)
  end

  def menu_status
    %w[active unavailable archived].include?(params[:menu_status].to_s) ? params[:menu_status].to_s : 'active'
  end

  def invalid_menu_operation(error)
    redirect_to menu_destination(@category&.id), alert: error.message, status: :see_other
  end

  def set_category
    @category = current_establishment.categories.find(params[:id])
  end

  def load_parent_categories
    @parent_categories = current_establishment.categories.not_archived.where.not(id: @category&.id).order(:name)
  end

  def uncategorized_category!
    category = current_establishment.categories
      .where.not(id: @category.id)
      .where('LOWER(name) = ?', 'sem categoria')
      .first

    category ||= current_establishment.categories.create!(name: 'Sem categoria', available: true)
    category.update!(archived_at: nil, available: true) if category.archived? || !category.available?
    category
  end

  def category_params
    values = params.require(:category).permit(:name, :available, :parent_id)
    current_establishment.categories.not_archived.find(values[:parent_id]) if values[:parent_id].present?
    values
  end
end
