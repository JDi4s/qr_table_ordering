class Staff::CategoriesController < Staff::BaseController
  include Staff::MenuContext
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
      AuditLogger.record(user: current_user, action: 'category_created', record: @category)
      redirect_to menu_return_path(@category.id), notice: 'Categoria criada.', status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      AuditLogger.record(user: current_user, action: 'category_updated', record: @category)
      redirect_to menu_return_path(@category.id), notice: 'Categoria atualizada.', status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.update!(archived_at: Time.current, available: false)
    AuditLogger.record(user: current_user, action: 'category_archived', record: @category)
    redirect_to menu_destination(@category.id), notice: 'Categoria arquivada.', status: :see_other
  end

  def restore
    @category.update!(archived_at: nil, available: true)
    AuditLogger.record(user: current_user, action: 'category_restored', record: @category)
    redirect_to menu_destination(@category.id), notice: 'Categoria restaurada.', status: :see_other
  end

  def purge
    raise Order::InvalidTransition, 'A categoria “Sem categoria” é necessária para guardar produtos sem categoria.' if @category.uncategorized?
    metadata = { deleted_category_id: @category.id, name: @category.name }
    @category.with_lock do
      if @category.menu_items.exists? || @category.children.exists?
        raise Order::InvalidTransition, 'Mova ou elimine primeiro os produtos e subcategorias desta categoria.'
      end

      @category.destroy!
      AuditLogger.record(user: current_user, action: 'category_deleted', metadata: metadata)
    end
    redirect_to menu_destination, notice: 'Categoria eliminada.', status: :see_other
  end

  def toggle_availability
    raise Order::InvalidTransition, 'Restaure primeiro a categoria arquivada.' if @category.archived?

    @category.update!(available: !@category.available?)
    AuditLogger.record(user: current_user, action: 'category_availability_changed', record: @category,
                       metadata: { available: @category.available? })
    redirect_to menu_destination(@category.id), status: :see_other
  end

  private

  def menu_destination(category_id = nil)
    menu_return_path(category_id)
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
