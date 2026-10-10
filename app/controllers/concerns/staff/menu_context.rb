module Staff::MenuContext
  extend ActiveSupport::Concern

  included do
    helper_method :menu_context_params, :menu_return_path, :menu_product_matches?, :selected_menu_kind
  end

  private

  def selected_menu_kind
    params[:menu_kind] == 'breakfast' ? 'breakfast' : 'lunch'
  end

  def menu_product_matches?(item)
    return item.scheduled_menu_visible? if params[:menu_section] == 'scheduled'
    item.normal_menu_visible?
  end

  def menu_context_params(category_id = nil)
    status = %w[active unavailable archived uncategorized].include?(params[:menu_status].to_s) ? params[:menu_status].to_s : 'active'
    selected_id = Integer(params[:open_category_id], exception: false) || category_id
    selected_id = nil unless current_establishment.categories.exists?(id: selected_id)
    { menu_kind: (selected_menu_kind if params[:menu_section] == 'scheduled'), menu_section: params[:menu_section].presence, menu_status: status, open_category_id: selected_id }.compact
  end

  def menu_return_path(category_id = nil)
    staff_menu_path(menu_context_params(category_id))
  end
end
