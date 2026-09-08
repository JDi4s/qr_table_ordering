class Staff::MenuController < Staff::BaseController
  def index
    @categories = current_establishment.categories.includes(:menu_items, :children).order(:name)
  end
end
