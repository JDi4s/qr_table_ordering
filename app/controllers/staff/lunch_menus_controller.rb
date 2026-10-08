class Staff::LunchMenusController < Staff::BaseController
  before_action :require_manager
  before_action :load_menu

  def edit
  end

  def update
    values = params.require(:lunch_menu).permit(:active, :starts_at, :ends_at, :individual_enabled, :combo_enabled, :combo_price, weekdays: [])
    values[:weekdays] = Array(values[:weekdays]).reject(&:blank?).map { |day| Integer(day, exception: false) }
    @lunch_menu.assign_attributes(values)
    @lunch_menu.individual_offers = selected_options(params[:individual_items], 'price')
    @lunch_menu.combo_groups = LunchMenu::GROUPS.keys.to_h do |key|
      [key, selected_options(params.dig(:combo_options, key), 'supplement')]
    end
    if @lunch_menu.save
      AuditLogger.record(user: current_user, action: 'lunch_menu_updated', record: @lunch_menu)
      redirect_to edit_staff_lunch_menu_path, notice: 'Menu de almoço guardado.', status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_menu
    @lunch_menu = current_establishment.lunch_menu || current_establishment.build_lunch_menu
    @products = current_establishment.menu_items.not_archived.includes(:category).order(:name)
  end

  def selected_options(raw, money_key)
    return [] unless raw.is_a?(ActionController::Parameters)
    raise ActionController::BadRequest if raw.keys.size > 1000
    raw.to_unsafe_h.filter_map do |id, option|
      next unless option.is_a?(Hash) && option['selected'] == '1'
      { 'menu_item_id' => Integer(id, exception: false), money_key => option[money_key].to_s.tr(',', '.') }
    end
  end
end
