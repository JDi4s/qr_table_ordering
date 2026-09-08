class Staff::MenuItemsController < Staff::BaseController
  before_action :require_manager, except: [:index, :show, :toggle_availability]
  before_action :set_menu_item, only: [:edit, :update, :destroy, :toggle_availability]
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
    @menu_item = MenuItem.new(menu_item_params)
    if @menu_item.save
      redirect_to staff_menu_path, notice: 'Produto criado.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  def edit; end
  def update
    if @menu_item.update(menu_item_params)
      redirect_to staff_menu_path, notice: 'Produto atualizado.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  def destroy
    @menu_item.destroy!
    redirect_to staff_menu_path, status: :see_other
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to staff_menu_path, alert: 'Produto com pedidos associados. Desative-o para preservar o histórico.'
  end
  def toggle_availability
    @menu_item.update!(available: !@menu_item.available?)
    redirect_to staff_menu_path, status: :see_other
  end
  private
  def set_menu_item
    @menu_item = current_establishment.menu_items.find(params[:id])
  end
  def menu_item_params
    values = params.require(:menu_item).permit(:name, :price, :category_id, :available)
    current_establishment.categories.find(values[:category_id]) if values[:category_id].present?
    values
  end
end
