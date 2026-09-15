class SupportTicketBroadcaster
  FILTERS = ['unresolved', *SupportTicket::STATUSES].freeze

  def self.admin_list_stream(status, establishment_id = nil)
    "support_list_admin_#{status}_#{establishment_id.presence || 'all'}"
  end

  def self.refresh(ticket)
    tickets = ticket.establishment.support_tickets.recent_first
    Turbo::StreamsChannel.broadcast_replace_to(
      "support_list_establishment_#{ticket.establishment_id}", target: 'support_ticket_list',
      partial: 'staff/support_tickets/list', locals: { tickets: tickets }
    )
    FILTERS.each do |status|
      [nil, ticket.establishment_id].each do |establishment_id|
        scope = SupportTicket.includes(:establishment).recent_first
        scope = scope.where(establishment_id: establishment_id) if establishment_id
        scope = status == 'unresolved' ? scope.unresolved : scope.where(status: status)
        Turbo::StreamsChannel.broadcast_replace_to(
          admin_list_stream(status, establishment_id), target: 'support_ticket_list',
          partial: 'admin/support_tickets/list', locals: { tickets: scope }
        )
      end
    end
    %w[admin staff].each do |audience|
      stream = "support_ticket_#{ticket.id}_#{audience}"
      Turbo::StreamsChannel.broadcast_replace_to(stream, target: "support_ticket_status_#{ticket.id}",
        partial: 'support_tickets/status', locals: { ticket: ticket })
      # Do not replace the composer for ordinary messages or priority changes.
      next unless ticket.saved_change_to_status? && ticket.saved_change_to_status.include?('resolved')

      Turbo::StreamsChannel.broadcast_replace_to(stream, target: "support_ticket_reply_#{ticket.id}",
        partial: "#{audience}/support_tickets/reply", locals: { ticket: ticket })
    end
  end

  def self.message_created(message)
    ticket = message.support_ticket
    %w[admin staff].each do |audience|
      Turbo::StreamsChannel.broadcast_append_to("support_ticket_#{ticket.id}_#{audience}",
        target: "support_ticket_messages_#{ticket.id}", partial: 'support_tickets/message',
        locals: { message: message })
    end
    refresh(ticket)
    title = message.from_support? ? 'Resposta do Suporte' : 'Nova mensagem de apoio'
    if !message.from_support? && !ticket.messages.where('id < ?', message.id).exists?
      title = 'Novo pedido de apoio'
    end
    notify(ticket, message.author, title: title)
  end

  def self.notify(ticket, author, title:)
    recipients = if author.platform_admin?
      ticket.establishment.users.where(role: 'manager')
    else
      User.where(role: 'platform_admin')
    end
    recipients.where(active: true, deleted_at: nil).where.not(id: author.id).find_each do |user|
      url = if user.platform_admin?
        Rails.application.routes.url_helpers.admin_support_ticket_path(ticket)
      else
        Rails.application.routes.url_helpers.staff_support_ticket_path(ticket)
      end
      Turbo::StreamsChannel.broadcast_append_to("support_notifications_user_#{user.id}",
        target: 'support_notifications', partial: 'support_tickets/notification',
        locals: { ticket: ticket, title: title, url: url })
    end
  end
end
