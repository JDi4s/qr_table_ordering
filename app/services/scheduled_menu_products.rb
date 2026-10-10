class ScheduledMenuProducts
  def self.add!(venue, item, kind:, group_key: nil, price: item.price)
    raise Order::InvalidTransition, 'Este produto não pertence ao estabelecimento.' unless item.establishment.id == venue.id
    menu = LunchMenu.for_management(venue, kind)
    if menu.new_record? && kind == 'breakfast'
      menu.starts_at = '08:00'; menu.ends_at = '11:30'; menu.combo_price = 5
    end
    menu.save! if menu.new_record?
    menu.with_lock do
      group = if group_key.present?
        menu.groups.find { |g| g['key'] == group_key }
      else
        menu.groups.find { |g| menu.product_matches?(item, g) }
      end
      if group_key.present? && (!group || !menu.product_matches?(item, group))
        raise Order::InvalidTransition, 'Escolhe um grupo compatível com o tipo do produto.'
      end
      offers = menu.individual_offers.reject { |row| row['menu_item_id'].to_i == item.id }
      offers << { 'menu_item_id' => item.id, 'price' => price.to_s }
      menu.individual_offers = offers
      if group
        options = menu.combo_groups.deep_dup
        options[group['key']] ||= []
        options[group['key']] << { 'menu_item_id' => item.id, 'supplement' => '0' } unless options[group['key']].any? { |row| row['menu_item_id'].to_i == item.id }
        menu.combo_groups = options
      end
      menu.save!
      item.update!(scheduled_menu_visible: true) unless item.scheduled_menu_visible?
    end
    menu
  end
end
