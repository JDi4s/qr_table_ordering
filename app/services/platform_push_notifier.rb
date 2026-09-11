class PlatformPushNotifier
  class << self
    def notify_platform(ticket, message = nil)
      subscriptions = User.where(role: 'platform_admin', active: true).includes(:staff_push_subscription)
        .filter_map(&:staff_push_subscription)
      body = message ? "Nova mensagem de #{ticket.establishment.name}." : "#{ticket.establishment.name}: #{ticket.subject}"
      deliver(subscriptions, title: 'Novo pedido de apoio', body: body,
             url: Rails.application.routes.url_helpers.admin_support_ticket_path(ticket), tag: "support-ticket-#{ticket.id}")
    end

    def notify_establishment(ticket, _message)
      subscriptions = ticket.establishment.users.where(role: 'manager', active: true, deleted_at: nil)
        .includes(:staff_push_subscription).filter_map(&:staff_push_subscription)
      deliver(subscriptions, title: 'Resposta do Suporte', body: ticket.subject,
             url: Rails.application.routes.url_helpers.staff_support_ticket_path(ticket), tag: "support-ticket-#{ticket.id}")
    end

    private

    def deliver(subscriptions, title:, body:, url:, tag:)
      return unless configured?

      subscriptions.each do |subscription|
        WebPush.payload_send(
          message: JSON.generate(title: title, body: body, icon: '/icon.svg', url: url, tag: tag),
          endpoint: subscription.endpoint, p256dh: subscription.p256dh, auth: subscription.auth,
          vapid: { subject: ENV['VAPID_SUBJECT'], public_key: ENV['VAPID_PUBLIC_KEY'], private_key: ENV['VAPID_PRIVATE_KEY'] },
          ttl: 300, urgency: 'high', open_timeout: 5, read_timeout: 5
        )
      rescue StandardError => error
        response_code = error.respond_to?(:response) ? error.response&.code.to_i : nil
        subscription.destroy! if [404, 410].include?(response_code)
        Rails.logger.warn("Push de apoio falhou: #{error.class}: #{error.message}")
      end
    end

    def configured?
      ENV['VAPID_PUBLIC_KEY'].present? && ENV['VAPID_PRIVATE_KEY'].present? && ENV['VAPID_SUBJECT'].present?
    end
  end
end
