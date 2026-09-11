class Staff::MenuController < Staff::BaseController
  def index
    @menu_status = %w[active unavailable archived uncategorized].include?(params[:menu_status].to_s) ? params[:menu_status].to_s : 'active'
    @open_category_id = Integer(params[:open_category_id], exception: false)
    @categories = current_establishment.categories.includes(:menu_items, :children).order(:name).to_a
    @uncategorized_category = @categories.find(&:uncategorized?)
    @menu_categories = @categories.reject(&:uncategorized?)
    @menu_roots = @menu_categories.select(&:root?).sort_by(&:name)
    @menu_counts = {
      'active' => @menu_categories.count { |category| !category.archived? && category.available? },
      'unavailable' => @menu_categories.count { |category| !category.archived? && !category.available? },
      'archived' => @menu_categories.count(&:archived?) + @menu_categories.sum { |category| category.menu_items.count(&:archived?) },
      'uncategorized' => @uncategorized_category&.menu_items&.size.to_i
    }
  end
end
