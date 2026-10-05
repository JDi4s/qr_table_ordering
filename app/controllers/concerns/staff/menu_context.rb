module Staff::MenuContext
  extend ActiveSupport::Concern

  included do
    helper_method :menu_context_params, :menu_return_path
  end

  private

  def menu_context_params(category_id = nil)
    status = %w[active unavailable archived uncategorized].include?(params[:menu_status].to_s) ? params[:menu_status].to_s : 'active'
    selected_id = Integer(params[:open_category_id], exception: false) || category_id
    selected_id = nil unless current_establishment.categories.exists?(id: selected_id)
    { menu_status: status, open_category_id: selected_id }.compact
  end

  def menu_return_path(category_id = nil)
    staff_menu_path(menu_context_params(category_id))
  end
end
