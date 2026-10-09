class Staff::ProductClassificationsController < Staff::BaseController
  before_action :require_manager
  def edit
    @products = current_establishment.menu_items.not_archived.includes(:category).order(:name)
  end
  def update
    values = params.require(:classification).permit(:product_kind, :preparation_key, :normal_menu_visible).to_h.reject { |_, value| value.blank? }
    ids = Array(params[:product_ids]).reject(&:blank?)
    raise Order::InvalidTransition, 'Seleciona produtos e pelo menos uma alteração.' if ids.empty? || values.empty? || ids.size > 5000
    CustomerMenuBroadcast.batch do
      MenuItem.transaction do
        products = current_establishment.menu_items.not_archived.where(id: ids)
        raise Order::InvalidTransition, 'Seleção de produtos inválida.' unless products.count == ids.uniq.size
        products.each { |product| product.update!(values) }
        AuditLogger.record(user: current_user, action: 'products_classified', record: current_establishment, metadata: { count: products.count, values: values })
      end
    end
    redirect_to staff_menu_path, notice: 'Produtos atualizados.', status: :see_other
  end
end
