class StaffPushNotifier
  def self.notify_service_call(service_call)
    new.notify_service_call(service_call)
  end

  def notify_service_call(service_call)
    return unless configured?

    User.where(establishment_id: service_call.table.establishment_id, active: true)
      .where(role: %w[staff manager])
      .includes(:staff_push_subscription)
      .filter_map(&:staff_push_subscription)
      .each { |subscription| send_notification(subscription, service_call) }
  end

  private

  def configured?
    ENV['VAPID_PUBLIC_KEY'].present? && ENV['VAPID_PRIVATE_KEY'].present? && ENV['VAPID_SUBJECT'].present?
  end

  def send_notification(subscription, service_call)
    WebPush.payload_send(
      message: JSON.generate(
        title: 'Chamada de cliente',
        body: "Mesa #{service_call.table.number} pediu assistência.",
        icon: '/icon.svg',
        url: '/staff/orders',
        tag: "service-call-#{service_call.id}"
      ),
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: {
        subject: ENV['VAPID_SUBJECT'],
        public_key: ENV['VAPID_PUBLIC_KEY'],
        private_key: ENV['VAPID_PRIVATE_KEY']
      },
      ttl: 300,
      urgency: 'high',
      open_timeout: 5,
      read_timeout: 5
    )
  rescue StandardError => error
    response_code = error.respond_to?(:response) ? error.response&.code.to_i : nil
    subscription.destroy! if [404, 410].include?(response_code)
    Rails.logger.warn("Push de chamada falhou: #{error.class}: #{error.message}")
  end
end
