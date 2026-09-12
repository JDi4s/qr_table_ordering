class LiveServiceSimulator
  DEFAULT_EVENTS = 10
  DEFAULT_INTERVAL_SECONDS = 30
  DEFAULT_FINAL_WAIT_SECONDS = 180

  NOTES = [
    'Cola com gelo e limão, por favor.',
    'Sem açúcar, por favor.',
    'Trazer tudo ao mesmo tempo.',
    'Uma das bebidas sem gelo.',
    'Cliente com alguma pressa.'
  ].freeze

  def initialize(establishment:, events: DEFAULT_EVENTS, interval_seconds: DEFAULT_INTERVAL_SECONDS,
                 final_wait_seconds: DEFAULT_FINAL_WAIT_SECONDS, output: $stdout, sleeper: Kernel,
                 random: Random.new)
    @establishment = establishment
    @events = Integer(events)
    @interval_seconds = Integer(interval_seconds)
    @final_wait_seconds = Integer(final_wait_seconds)
    @output = output
    @sleeper = sleeper
    @random = random
    @run_id = Time.current.strftime('%Y%m%d-%H%M%S')
    @orders = []
    @service_calls = []
  end

  def run!
    validate!
    print_header

    events.times do |index|
      create_event(index)
      wait(interval_seconds) if index < events - 1
    end

    if final_wait_seconds.positive?
      say("\nTodos os eventos foram enviados. Tens #{final_wait_seconds} segundos para terminar o atendimento.")
      wait(final_wait_seconds)
    end

    print_summary
    true
  rescue StandardError => error
    Rails.logger.error("[ENSAIO #{@run_id}] #{error.class}: #{error.message}\n#{error.backtrace&.first(20)&.join("\n")}")
    say("\nERRO — #{error.class}: #{error.message}")
    say('O ensaio parou. Consulta o ficheiro de logs indicado pelo comando.')
    raise
  end

  private

  attr_reader :establishment, :events, :interval_seconds, :final_wait_seconds,
              :output, :sleeper, :random, :run_id, :orders, :service_calls

  def validate!
    raise ArgumentError, 'Este ensaio só pode ser executado no Café Teste.' unless establishment.slug == 'cafe-teste'
    raise ArgumentError, 'O Café Teste está suspenso.' unless establishment.active?
    raise ArgumentError, 'EVENTS deve estar entre 1 e 30.' unless events.between?(1, 30)
    raise ArgumentError, 'INTERVAL_SECONDS deve estar entre 0 e 300.' unless interval_seconds.between?(0, 300)
    raise ArgumentError, 'FINAL_WAIT_SECONDS deve estar entre 0 e 900.' unless final_wait_seconds.between?(0, 900)
    raise ArgumentError, 'São necessárias pelo menos duas mesas ativas no Café Teste.' if active_tables.size < 2
    raise ArgumentError, 'São necessários pelo menos três produtos disponíveis no Café Teste.' if available_items.size < 3
  end

  def print_header
    say("ENSAIO DE SERVIÇO — Café Teste — #{run_id}")
    say("Eventos: #{events} | intervalo: #{interval_seconds}s | verificação final: #{final_wait_seconds}s")
    say("Mesas: #{active_tables.map(&:number).join(', ')}")
    say("Notificações push: #{push_status}")
    say("\nMantém aberto o painel de Pedidos e trata os pedidos/chamadas como num serviço real.")
    say("Os pedidos ficam marcados com [ENSAIO] e não serão apagados.\n")
  end

  def create_event(index)
    if service_call_turn?(index) && create_service_call
      return
    end

    create_order(index)
  end

  def create_order(index)
    table = active_tables[index % active_tables.length]
    chosen_items = available_items.sample(random.rand(1..[3, available_items.length].min), random: random)
    customer_token = "ensaio-#{run_id}-#{index + 1}-#{SecureRandom.hex(4)}"

    order = table.orders.new(
      status: 'pending',
      customer_token: customer_token,
      submission_token: SecureRandom.hex(16),
      note: "[ENSAIO #{run_id}] #{NOTES[index % NOTES.length]}"
    )
    chosen_items.each do |menu_item|
      quantity = random.rand(1..2)
      order.order_items.build(menu_item: menu_item, quantity: quantity, unit_price: menu_item.price, status: 'pending')
    end
    order.total = order.order_items.sum { |item| item.unit_price * item.quantity }
    order.save!
    orders << order

    names = order.order_items.map { |item| "#{item.quantity}x #{item.display_name}" }.join(', ')
    say("[#{timestamp}] PEDIDO ##{order.id} · Mesa #{table.number} · #{names} · #{format('%.2f', order.total)} €")
  end

  def create_service_call
    table = active_tables.find do |candidate|
      !candidate.service_calls.where(status: %w[pending claimed]).exists? &&
        !candidate.service_calls.where('created_at > ?', 60.seconds.ago).exists?
    end
    return false unless table

    service_call = ServiceCall.request_for!(table)
    service_calls << service_call
    say("[#{timestamp}] CHAMADA ##{service_call.id} · Mesa #{table.number}")
    true
  end

  def service_call_turn?(index)
    (index % 4) == 1
  end

  def print_summary
    orders.each(&:reload)
    service_calls.each(&:reload)

    completed_orders = orders.count { |order| order.denied? || (order.served? && order.paid?) }
    pending_orders = orders.count(&:pending?)
    accepted_orders = orders.count(&:accepted?)
    served_unpaid_orders = orders.count { |order| order.served? && !order.paid? }
    resolved_calls = service_calls.count(&:resolved?)

    say("\nRESULTADO DO ENSAIO #{run_id}")
    say("Pedidos criados e guardados: #{orders.size}/#{orders.size} — OK")
    say("Pedidos totalmente concluídos: #{completed_orders}/#{orders.size}")
    say("Por tratar: #{pending_orders} | aceites por servir: #{accepted_orders} | servidos por pagar: #{served_unpaid_orders}")
    say("Chamadas resolvidas: #{resolved_calls}/#{service_calls.size}")

    unfinished = pending_orders + accepted_orders + served_unpaid_orders + (service_calls.size - resolved_calls)
    if unfinished.zero?
      say('RESULTADO: OK — todo o fluxo manual foi concluído.')
    else
      say("RESULTADO: ATENÇÃO — ficaram #{unfinished} ações por concluir no painel.")
    end
  end

  def active_tables
    @active_tables ||= establishment.tables.where(active: true, deleted_at: nil).order(:number).to_a
  end

  def available_items
    @available_items ||= establishment.menu_items.not_archived.includes(category: :parent).where(available: true)
      .select { |item| item.category.visible_to_customers? }
  end

  def push_status
    configured = %w[VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY VAPID_SUBJECT].all? { |key| ENV[key].present? }
    subscriptions = establishment.users.where(active: true, role: %w[staff manager]).joins(:staff_push_subscription).count
    return 'não configuradas' unless configured
    return 'configuradas, mas nenhum funcionário tem subscrição ativa' if subscriptions.zero?

    "ativas para #{subscriptions} funcionário(s)"
  end

  def wait(seconds)
    sleeper.sleep(seconds)
  end

  def timestamp
    Time.current.strftime('%H:%M:%S')
  end

  def say(message)
    output.puts(message)
    output.flush if output.respond_to?(:flush)
  end
end
