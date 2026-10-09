class Staff::ProductClassificationsController < Staff::BaseController
  before_action :require_manager

  def edit
    @show_all = params[:scope] == 'all'
    products = current_establishment.menu_items.not_archived
    @areas = current_establishment.available_production_areas
    missing = products.where(product_kind: 'unclassified')
    missing = missing.or(products.where(production_area_id: nil)) if current_establishment.service_division_enabled?
    @unclassified_count = missing.count
    @products = (@show_all ? products : missing).includes(:category).order(:name)
  end

  def update
    raw = params.require(:classification)
    values = raw.permit(:product_kind).to_h
    kind = values['product_kind']
    raise Order::InvalidTransition, 'Escolhe o tipo de produto.' unless MenuItem::PRODUCT_KINDS.except('unclassified').key?(kind)
    if current_establishment.service_division_enabled? && raw[:production_area_id].present?
      area = current_establishment.available_production_areas.find_by(id: raw[:production_area_id])
      raise Order::InvalidTransition, 'Escolhe uma área deste estabelecimento.' unless area
      values.merge!('production_area_id' => area.id, 'preparation_key' => area.preparation_key)
    end
    ids = Array(params[:product_ids]).reject(&:blank?)
    raise Order::InvalidTransition, 'Seleciona pelo menos um produto.' if ids.empty? || ids.size > 5000
    CustomerMenuBroadcast.batch do
      MenuItem.transaction do
        products = current_establishment.menu_items.not_archived.where(id: ids)
        raise Order::InvalidTransition, 'Seleção de produtos inválida.' unless products.count == ids.uniq.size
        if current_establishment.service_division_enabled? && !values['production_area_id'] && products.where(production_area_id: nil).exists?
          raise Order::InvalidTransition, 'Escolhe a área onde estes produtos são preparados.'
        end
        products.each { |product| product.update!(values) }
        AuditLogger.record(user: current_user, action: 'products_classified', record: current_establishment, metadata: { count: products.count, values: values })
      end
    end
    redirect_to edit_staff_product_classification_path(scope: ('all' if params[:scope] == 'all')), notice: "#{ids.uniq.size} produto(s) classificado(s).", status: :see_other
  end
end
