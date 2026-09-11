class Staff::MenuItemsController < Staff::BaseController
  rescue_from Order::InvalidTransition, with: :invalid_menu_operation
  before_action :require_manager, except: [:index, :show, :toggle_availability]
  before_action :set_menu_item, only: [:edit, :update, :destroy, :toggle_availability, :restore, :purge]
  before_action :load_recommendation_options, only: [:new, :create, :edit, :update]
  before_action :load_production_area_options, only: [:new, :create, :edit, :update]

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
    @menu_item = MenuItem.new
    @menu_item.assign_attributes(menu_item_params)

    if @menu_item.errors.empty? && @menu_item.save
      sync_recommendations!
      redirect_to staff_menu_path(anchor: "category-#{@menu_item.category_id}"), notice: 'Produto criado.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attributes = menu_item_params
    if @menu_item.errors.empty? && @menu_item.update(attributes)
      sync_recommendations!
      redirect_to staff_menu_path(anchor: "category-#{@menu_item.category_id}"), notice: 'Produto atualizado.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @menu_item.update!(archived_at: Time.current, available: false)
    redirect_to menu_destination(@menu_item.category_id), notice: 'Produto arquivado.', status: :see_other
  end

  def restore
    @menu_item.update!(archived_at: nil, available: true)
    redirect_to menu_destination(@menu_item.category_id), notice: 'Produto restaurado.', status: :see_other
  end

  def purge
    if @menu_item.used_by_ongoing_order?
      raise Order::InvalidTransition, 'Este produto está num pedido em curso. Conclua ou anule primeiro o pedido.'
    end

    category_id = @menu_item.category_id
    metadata = { deleted_menu_item_id: @menu_item.id, name: @menu_item.name, category_id: category_id }
    @menu_item.destroy!
    AuditLogger.record(user: current_user, action: 'menu_item_deleted', metadata: metadata)

    redirect_to menu_destination(category_id), notice: 'Produto eliminado definitivamente.', status: :see_other
  end

  def purge_uncategorized
    category = uncategorized_category
    items = category ? category.menu_items.to_a : []
    deleted, blocked = delete_products(items)

    AuditLogger.record(
      user: current_user,
      action: 'uncategorized_menu_items_deleted',
      metadata: { deleted_products: deleted, blocked_products: blocked }
    ) if deleted.positive?

    redirect_to staff_menu_path(menu_status: 'uncategorized'),
      notice: bulk_delete_message(deleted, blocked), status: :see_other
  end

  def purge_archived
    categories = current_establishment.categories.includes(:menu_items, :children).to_a
    archived_categories = archived_category_tree(categories)
    archived_ids = archived_categories.map(&:id)
    products = current_establishment.menu_items.where.not(archived_at: nil)
    uncategorized_id = uncategorized_category&.id
    products = products.where.not(category_id: uncategorized_id) if uncategorized_id
    products = products.to_a
    products |= current_establishment.menu_items.where(category_id: archived_ids).to_a if archived_ids.any?
    deleted = blocked = deleted_categories = 0
    Category.transaction do
      deleted, blocked = delete_products(products)
      deleted_categories = delete_category_tree(archived_categories)
    end

    AuditLogger.record(
      user: current_user,
      action: 'archived_menu_records_deleted',
      metadata: { deleted_products: deleted, deleted_categories: deleted_categories, blocked_products: blocked }
    ) if deleted.positive? || deleted_categories.positive?

    redirect_to staff_menu_path(menu_status: 'archived'),
      notice: bulk_delete_message(deleted, blocked, deleted_categories), status: :see_other
  end

  def toggle_availability
    raise Order::InvalidTransition, 'Restaure primeiro o produto arquivado.' if @menu_item.archived?

    @menu_item.update!(available: !@menu_item.available?)
    redirect_to menu_destination(@menu_item.category_id), status: :see_other
  end

  private

  def menu_destination(category_id = nil)
    staff_menu_path(menu_status: menu_status, open_category_id: category_id)
  end

  def menu_status
    %w[active unavailable archived uncategorized].include?(params[:menu_status].to_s) ? params[:menu_status].to_s : 'active'
  end

  def invalid_menu_operation(error)
    redirect_to menu_destination(@menu_item&.category_id), alert: error.message, status: :see_other
  end

  def set_menu_item
    @menu_item = current_establishment.menu_items.find(params[:id])
  end

  def uncategorized_category(excluding: nil)
    scope = current_establishment.categories.where('LOWER(name) = ?', 'sem categoria')
    scope = scope.where.not(id: excluding) if excluding
    scope.first
  end

  def uncategorized_category!
    category = uncategorized_category
    category ||= current_establishment.categories.create!(name: 'Sem categoria', available: true)
    category.update!(archived_at: nil, available: true, parent_id: nil) if category.archived? || !category.available? || category.parent_id?
    category
  end

  def delete_products(items)
    removable, blocked = items.uniq.partition { |item| !item.used_by_ongoing_order? }
    MenuItem.transaction { removable.each(&:destroy!) }
    [removable.size, blocked.size]
  end

  def archived_category_tree(categories)
    by_parent = categories.group_by(&:parent_id)
    selected = []
    visit = lambda do |category, inherited_archived|
      inside_archived = inherited_archived || category.archived?
      selected << category if inside_archived && !category.uncategorized?
      Array(by_parent[category.id]).each { |child| visit.call(child, inside_archived) }
    end
    Array(by_parent[nil]).each { |root| visit.call(root, false) }
    selected
  end

  def delete_category_tree(categories)
    return 0 if categories.empty?

    target_ids = categories.map(&:id)
    parent_ids = categories.index_by(&:id).transform_values(&:parent_id)
    depth = lambda do |category|
      value = 0
      parent_id = category.parent_id
      while parent_id && target_ids.include?(parent_id)
        value += 1
        parent_id = parent_ids[parent_id]
      end
      value
    end

    destination = nil
    Category.transaction do
      categories.sort_by { |category| -depth.call(category) }.each do |category|
        category.reload
        if category.menu_items.exists?
          destination ||= uncategorized_category!
          category.menu_items.update_all(category_id: destination.id, updated_at: Time.current)
          category.menu_items.reset
        end
        category.children.update_all(parent_id: category.parent_id, updated_at: Time.current)
        category.children.reset
        category.destroy!
      end
    end
    categories.size
  end

  def bulk_delete_message(products, blocked, categories = 0)
    parts = []
    parts << "#{products} #{products == 1 ? 'produto eliminado' : 'produtos eliminados'}" if products.positive?
    parts << "#{categories} #{categories == 1 ? 'categoria eliminada' : 'categorias eliminadas'}" if categories.positive?
    parts << "#{blocked} #{blocked == 1 ? 'produto foi mantido em “Sem categoria” por estar' : 'produtos foram mantidos em “Sem categoria” por estarem'} em pedidos em curso" if blocked.positive?
    parts.presence&.join('. ')&.+('.') || 'Não existem registos que possam ser eliminados.'
  end

  def menu_item_params
    values = params.require(:menu_item).permit(
      :name,
      :description,
      :price,
      :category_id,
      :production_area_id,
      :available,
      :image,
      recommended_menu_item_ids: []
    )
    values.delete(:recommended_menu_item_ids)
    category = current_establishment.categories.not_archived.find_by(id: values[:category_id]) if values[:category_id].present?
    unless category
      @menu_item.errors.add(:category, 'tem de ser uma categoria disponível')
      values.delete(:category_id)
    end
    area = current_establishment.available_production_areas.find_by(id: values[:production_area_id]) if values[:production_area_id].present?
    if current_establishment.production_areas_enabled? && values[:production_area_id].present? && !area
      @menu_item.errors.add(:production_area, 'não está disponível para este estabelecimento')
      values.delete(:production_area_id)
    elsif !current_establishment.production_areas_enabled?
      values.delete(:production_area_id)
    end
    values
  end

  def load_recommendation_options
    @recommendation_options = current_establishment.menu_items.not_archived.includes(:category).order(:name)
  end

  def load_production_area_options
    @production_areas = current_establishment.available_production_areas
  end

  def sync_recommendations!
    ids = Array(params.dig(:menu_item, :recommended_menu_item_ids)).filter_map { |id| Integer(id, exception: false) }
    ids = current_establishment.menu_items.not_archived.where(id: ids).where.not(id: @menu_item.id).pluck(:id)
    @menu_item.recommendations.where.not(recommended_menu_item_id: ids).delete_all
    ids.each do |id|
      @menu_item.recommendations.find_or_create_by!(recommended_menu_item_id: id)
    end
  end
end
