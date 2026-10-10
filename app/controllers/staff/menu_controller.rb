class Staff::MenuController < Staff::BaseController
  include Staff::MenuContext

  def index
    if params[:menu_section] == 'scheduled'
      @selected_menu = LunchMenu.for_management(current_establishment, selected_menu_kind)
      if @selected_menu.new_record? && selected_menu_kind == 'breakfast'
        @selected_menu.starts_at = '08:00'; @selected_menu.ends_at = '11:30'
      end
      @scheduled_groups = @selected_menu.groups
      @scheduled_ids = (@selected_menu.individual_offers + @selected_menu.combo_groups.values.flatten).map { |row| row['menu_item_id'].to_i }
      @scheduled_products = current_establishment.menu_items.where(scheduled_menu_visible: true).includes(:category).order(:name).to_a
    end
    @menu_status = %w[active unavailable archived uncategorized].include?(params[:menu_status].to_s) ? params[:menu_status].to_s : 'active'
    @open_category_id = Integer(params[:open_category_id], exception: false)
    @categories = current_establishment.categories.includes(:menu_items, :children).order(:name).to_a
    @uncategorized_category = @categories.find(&:uncategorized?)
    @menu_categories = @categories.reject(&:uncategorized?)
    @menu_open_category_ids = []
    by_id = @menu_categories.index_by(&:id)
    selected = by_id[@open_category_id]
    while selected && !@menu_open_category_ids.include?(selected.id)
      @menu_open_category_ids << selected.id
      selected = by_id[selected.parent_id]
    end
    @menu_roots = @menu_categories.select(&:root?).sort_by(&:name)
    @menu_children = @menu_categories.group_by(&:parent_id)
    @menu_category_states = {}
    @menu_roots.each { |category| collect_states(category, archived: false, unavailable: false) }
    @menu_counts = {
      'active' => @menu_category_states.count { |_, state| !state[:archived] && !state[:unavailable] },
      'unavailable' => @menu_category_states.sum do |id, state|
        next 0 if state[:archived]
        category = @menu_categories.find { |record| record.id == id }
        (state[:unavailable] ? 1 : 0) + category.menu_items.count { |item| !item.archived? && (state[:unavailable] || !item.available?) }
      end,
      'archived' => @menu_categories.count(&:archived?) + @menu_categories.sum { |category| category.menu_items.count(&:archived?) },
      'uncategorized' => @uncategorized_category&.menu_items&.size.to_i
    }
    @menu_counts['active'] = matching_category_ids('active').size
    @menu_counts['unavailable'] = @menu_categories.sum do |category|
      state = @menu_category_states[category.id]
      next 0 if state[:archived]
      items = category.menu_items.select { |item| menu_product_matches?(item) && !item.archived? }
      (state[:unavailable] && items.any? ? 1 : 0) + items.count { |item| state[:unavailable] || !item.available? }
    end
    @menu_counts['archived'] = @menu_categories.sum do |category|
      items = category.menu_items.select { |item| menu_product_matches?(item) }
      (category.archived? && items.any? ? 1 : 0) + items.count(&:archived?)
    end
    @menu_counts['uncategorized'] = @uncategorized_category&.menu_items&.count { |item| menu_product_matches?(item) }.to_i
    @menu_status = 'active' if @menu_status == 'uncategorized' && @menu_counts['uncategorized'].zero?
    @menu_visible_category_ids = matching_category_ids(@menu_status)
  end

  private

  def collect_states(category, archived:, unavailable:)
    state = { archived: archived || category.archived?, unavailable: unavailable || !category.available? }
    @menu_category_states[category.id] = state
    Array(@menu_children[category.id]).each { |child| collect_states(child, **state) }
  end

  def matching_category_ids(status)
    ids = []
    visit = lambda do |category|
      state = @menu_category_states.fetch(category.id)
      child_matches = Array(@menu_children[category.id]).map { |child| visit.call(child) }.any?
      own_match = case status
      when 'active'
        !state[:archived] && !state[:unavailable]
      when 'unavailable'
        !state[:archived] && (state[:unavailable] || category.menu_items.any? { |item| !item.archived? && !item.available? })
      when 'archived'
        state[:archived] || category.menu_items.any?(&:archived?)
      else
        false
      end
      own_match &&= category.menu_items.any? { |item| menu_product_matches?(item) }
      matches = own_match || child_matches
      ids << category.id if matches
      matches
    end
    @menu_roots.each { |category| visit.call(category) }
    ids
  end
end
