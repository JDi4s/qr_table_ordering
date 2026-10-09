class PreparationNotifier
  def self.call(order)
    return unless order.establishment.service_division_enabled?
    new_work = order.saved_change_to_status? && order.accepted?
    area_ids = order.preparation_tasks.distinct.pluck(:production_area_id).compact
    order.establishment.users.where(active: true, deleted_at: nil).find_each do |user|
      next if user.preparation_staff? && !user.production_areas.where(active: true, id: area_ids).exists?
      # Preparation messages carry no order contents; each board reloads its authorized scope.
      message = "<turbo-stream action=\"append\" target=\"preparation_notifications\"><template><span data-controller=\"preparation-refresh\" data-sound=\"#{new_work && user.preparation_staff? ? '1' : '0'}\"></span></template></turbo-stream>"
      ActionCable.server.broadcast("preparation_user_#{user.id}", message)
      next unless new_work && user.preparation_staff?
      user.staff_push_subscriptions.each do |subscription|
        StaffPushNotifier.new.send(:send_notification, subscription, title: 'Novo pedido para preparar', body: "Mesa #{order.table.number}: há artigos para o teu posto.", tag: "preparation-#{order.id}", url: '/staff/preparations') if ENV['VAPID_PUBLIC_KEY'].present?
      end
    end
  end

  def self.ready(task)
    task.order.establishment.users.where(active: true, deleted_at: nil).find_each do |user|
      next if user.preparation_staff?
      ActionCable.server.broadcast("preparation_user_#{user.id}", '<turbo-stream action="append" target="preparation_notifications"><template><span data-controller="preparation-refresh" data-sound="1"></span></template></turbo-stream>')
      user.staff_push_subscriptions.each do |subscription|
        StaffPushNotifier.new.send(:send_notification, subscription, title: 'Preparação pronta', body: "Mesa #{task.order.table.number}: #{task.production_area&.name || 'preparação'} pronta para entrega.", tag: "ready-#{task.id}", url: '/staff/preparations') if ENV['VAPID_PUBLIC_KEY'].present?
      end
    end
  end
end
