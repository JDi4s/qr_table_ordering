class Staff::LunchMenusController < Staff::BaseController
  before_action :require_manager
  before_action :load_menu

  def edit
  end

  def update
    values = params.require(:lunch_menu).permit(:active, :starts_at, :ends_at, :individual_enabled, :combo_enabled, :combo_price, weekdays: [])
    values[:weekdays] = Array(values[:weekdays]).reject(&:blank?).map { |day| Integer(day, exception: false) }
    @lunch_menu.assign_attributes(values)
    if params[:groups].present?
      raise ActionController::BadRequest unless params[:groups].is_a?(ActionController::Parameters) && params[:groups].keys.size <= 8 && params[:groups].values.all? { |g| g.is_a?(ActionController::Parameters) }
      @lunch_menu.group_definitions = params.require(:groups).to_unsafe_h.values.filter_map do |group|
        next if group['name'].blank?
        { 'key' => group['key'].to_s, 'name' => group['name'].to_s.strip, 'types' => group['types'].to_s.split(','), 'optional' => group['optional'] == '1' }
      end
    end
    @lunch_menu.individual_offers = selected_options(params[:individual_items], 'price')
    @lunch_menu.combo_groups = @lunch_menu.groups.map { |group| group['key'] }.to_h do |key|
      [key, selected_options(params.dig(:combo_options, key), 'supplement')]
    end
    if @lunch_menu.save
      AuditLogger.record(user: current_user, action: 'lunch_menu_updated', record: @lunch_menu)
      redirect_to edit_staff_lunch_menu_path(menu_kind: @kind), notice: "#{@kind == 'lunch' ? 'Menu de almoço' : 'Pequeno-almoço'} guardado.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_menu
    @kind = params[:menu_kind] == 'breakfast' ? 'breakfast' : 'lunch'
    @lunch_menu = current_establishment.scheduled_menus.find_or_initialize_by(menu_kind: @kind)
    if @lunch_menu.new_record? && @kind == 'breakfast'
      @lunch_menu.starts_at = '08:00'; @lunch_menu.ends_at = '11:00'; @lunch_menu.combo_price = 5
    end
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
