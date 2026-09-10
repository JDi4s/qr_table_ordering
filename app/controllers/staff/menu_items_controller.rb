class Staff::MenuItemsController < Staff::BaseController
  before_action :require_manager, except: [:index, :show, :toggle_availability]
  before_action :set_menu_item, only: [:edit, :update, :destroy, :toggle_availability, :restore]
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
    redirect_to staff_menu_path, notice: 'Produto arquivado.', status: :see_other
  end

  def restore
    @menu_item.update!(archived_at: nil, available: true)
    redirect_to staff_menu_path, notice: 'Produto restaurado.', status: :see_other
  end

  def toggle_availability
    raise Order::InvalidTransition, 'Restaure primeiro o produto arquivado.' if @menu_item.archived?

    @menu_item.update!(available: !@menu_item.available?)
    redirect_to staff_menu_path, status: :see_other
  end

  private

  def set_menu_item
    @menu_item = current_establishment.menu_items.find(params[:id])
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
