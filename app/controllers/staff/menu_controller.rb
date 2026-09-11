class Staff::MenuController < Staff::BaseController
  def index
    @menu_status = %w[active unavailable archived].include?(params[:menu_status].to_s) ? params[:menu_status].to_s : 'active'
    @open_category_id = Integer(params[:open_category_id], exception: false)
    @categories = current_establishment.categories.includes(:menu_items, :children).order(:name)
  end
end
