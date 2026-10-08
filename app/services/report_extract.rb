require 'set'

# One accounting basis throughout: active payments received in the selected dates.
# Partial payments contribute only their own quantities and captured amounts.
class ReportExtract
  WEEKDAYS = %w[Domingo Segunda Terça Quarta Quinta Sexta Sábado].freeze
  TIME_BANDS = [[0, 8], [8, 11], [11, 14], [14, 17], [17, 20], [20, 24]].freeze

  def initialize(establishment:, period:, employee: nil)
    @venue, @period, @employee = establishment, period, employee
  end

  def data
    @payments = payments(@period.from, @period.to).to_a
    @total = @payments.sum(0.to_d, &:amount)
    @products, @categories, @tables = {}, {}, {}
    @days, @hours, @weekday_hours = {}, {}, {}
    @discounts = 0.to_d
    @payments.each { |payment| collect(payment) }
    @units = @products.values.sum { |row| row[:quantity] }
    @orders = @payments.map(&:order_id).uniq.size
    days = (@period.to - effective_start).to_i + 1
    reviews = GoogleReviewStatistics.new(establishment: @venue, from: effective_start, to: @period.to)
    {
      title: 'Relatório do período', establishment: @venue.name,
      period: "#{effective_start.strftime('%d/%m/%Y')} - #{@period.to.strftime('%d/%m/%Y')}",
      subtitle: @employee ? "Recebimentos por #{@employee.display_identity}" : 'Resumo do negócio e detalhe do período escolhido.',
      stats: [['Faturação recebida', money(@total)], ['Pedidos com pagamento', @orders.to_s],
              ['Artigos vendidos', @units.to_s], ['Faturação média / dia', money(@total / days)],
              ['Pedidos médios / dia', decimal(@orders.to_f / days)], ['Artigos por pedido', decimal(@orders.zero? ? 0 : @units.to_f / @orders)]],
      sections: summary_sections + [reviews.section] + product_sections + payment_sections + time_sections,
      notes: [
        'Faturação = pagamentos ativos recebidos no período, após reduções de preço. Pagamentos anulados ficam excluídos. Quantidades = unidades desses pagamentos, incluindo pagamentos parciais.',
        'As médias usam dias de calendário. Sem um calendário de funcionamento registado, os mínimos consideram apenas dias e horas com recebimentos. Horários referem-se ao pagamento, no fuso da aplicação.',
        'Categorias usam a classificação atual do produto. Produtos sem vendas não entram no ranking dos menos vendidos. Reduções de preço são calculadas face ao preço original guardado no pedido.',
        'Anulações e cancelamentos apresentados são do estabelecimento inteiro, mesmo quando os recebimentos estão filtrados por funcionário.',
        reviews.note
      ],
      payment_rows: @payments.map do |p|
        t = p.paid_at.in_time_zone
        [t.strftime('%d/%m/%Y'), t.strftime('%H:%M'), p.order_id.to_s, p.order.table.display_number.to_s,
         p.user.display_identity, method_label(p.payment_method), money(p.amount)]
      end
    }
  end

  private

  def payments(first, last)
    scope = @venue.payments.active.where(paid_at: first.beginning_of_day...(last + 1).beginning_of_day)
    scope = scope.where(user_id: @employee.id) if @employee
    scope.includes(:user, order: :table, payment_items: { order_item: { menu_item: :category } }).order(:paid_at, :id)
  end

  def effective_start
    return @period.from unless @period.view == 'lifetime'
    [@venue.created_at.in_time_zone.to_date, @payments.first&.paid_at&.in_time_zone&.to_date].compact.min
  end

  def bucket(hash, key, name)
    hash[key] ||= { name: name, amount: 0.to_d, quantity: 0, orders: Set.new }
  end

  def collect(p)
    time = p.paid_at.in_time_zone
    day = bucket(@days, time.to_date, time.strftime('%d/%m/%Y'))
    hour = bucket(@hours, time.hour, hour_label(time.hour))
    table = bucket(@tables, p.order.table_id, "Mesa #{p.order.table.display_number}")
    bin = TIME_BANDS.index { |first, last| time.hour >= first && time.hour < last }
    period = bucket(@weekday_hours, [time.wday, bin], WEEKDAYS[time.wday])
    [day, hour, table, period].each { |b| b[:amount] += p.amount; b[:orders].add(p.order_id) }
    p.payment_items.each do |item|
      oi = item.order_item
      product = bucket(@products, oi.menu_item_id || "item_#{oi.id}", oi.display_name)
      cat = oi.menu_item&.category
      category = bucket(@categories, cat&.id, cat&.name || 'Sem categoria / produto eliminado')
      [product, category].each { |b| b[:quantity] += item.quantity; b[:amount] += item.amount }
      original = oi.original_unit_price
      @discounts += [(original.to_d - item.unit_price) * item.quantity, 0.to_d].max if original
    end
    unallocated = p.amount - p.payment_items.sum(0.to_d, &:amount)
    bucket(@categories, :unallocated, 'Sem detalhe de artigos')[:amount] += unallocated unless unallocated.zero?
  end

  def summary_sections
    previous_first, previous_last = previous_range
    comparisons = [['Período anterior', previous_first, previous_last],
                   ['Mesmo período do ano anterior', effective_start - 1.year, @period.to - 1.year]]
    rows = comparisons.map do |label, first, last|
      previous = payments(first, last).to_a
      value = previous.sum(0.to_d, &:amount)
      count = previous.map(&:order_id).uniq.size
      ["#{label}\n#{first.strftime('%d/%m/%Y')} - #{last.strftime('%d/%m/%Y')}", previous.empty? ? 'Sem dados' : money(value),
       previous.empty? ? 'Sem comparação' : "#{money(@total - value)} / #{change(@total, value)}",
       previous.empty? ? '-' : "#{count} / #{change(@orders, count)}"]
    end
    series = chart_series
    [ { title: 'Comparação de períodos', headers: ['Comparação', 'Faturação anterior', 'Variação € / %', 'Pedidos anteriores / %'], rows: rows },
      { title: 'Evolução da faturação', chart_rows: series, rows: [] },
      { title: 'Destaques do período', headers: ['Indicador', 'Resultado'], rows: [
        ['Dia com maior faturação', extreme(@days, :amount, :max)],
        ['Dia com menor faturação', extreme(@days, :amount, :min)],
        ['Hora com maior faturação', extreme(@hours, :amount, :max)],
        ['Hora com menor faturação', extreme(@hours, :amount, :min)],
        ['Hora com mais pedidos', extreme(@hours, :orders, :max)],
        ['Hora com menos pedidos', extreme(@hours, :orders, :min)] ] } ]
  end

  def previous_range
    if @period.view == 'month' && @period.to == @period.from.end_of_month
      d = @period.from - 1.month
      [d.beginning_of_month, d.end_of_month]
    else
      days = (@period.to - effective_start).to_i + 1
      [effective_start - days, effective_start - 1]
    end
  end

  def chart_series
    # Never discard dates: long intervals are aggregated rather than clipped.
    monthly = (@period.to - effective_start).to_i > 62
    groups = @days.group_by { |date, _| monthly ? date.beginning_of_month : date }
    groups.sort.map do |date, entries|
      amount = entries.sum(0.to_d) { |_, row| row[:amount] }
      { label: date.strftime(monthly ? '%m/%Y' : '%d/%m/%Y'), value: amount.to_f, display: money(amount) }
    end
  end

  def product_sections
    products = @products.values
    top_qty = products.sort_by { |r| [-r[:quantity], -r[:amount], r[:name]] }
    top_rev = products.sort_by { |r| [-r[:amount], r[:name]] }
    bottom_qty = products.sort_by { |r| [r[:quantity], r[:amount], r[:name]] }
    bottom_rev = products.sort_by { |r| [r[:amount], r[:name]] }
    sections = [{ title: 'Produtos e categorias', new_page: true, headers: ['Indicador', 'Resultado'], rows: [
      ['Produto mais vendido', product_label(top_qty.first)], ['Produto menos vendido', product_label(bottom_qty.first)],
      ['Produto com maior faturação', product_label(top_rev.first)],
      ['Categoria mais vendida', product_label(@categories.values.max_by { |r| r[:quantity] })] ] }]
    [['Top 5 produtos por quantidade', top_qty], ['Top 5 produtos por faturação', top_rev],
     ['Top 5 menos vendidos por quantidade', bottom_qty], ['Top 5 com menor faturação', bottom_rev]].each do |title, list|
      sections << { title: title, headers: ['Produto', 'Unidades', 'Faturação'], rows: list.first(5).map { |r| [r[:name], r[:quantity], money(r[:amount])] } }
    end
    sections << { title: 'Faturação por categoria', headers: ['Categoria', 'Unidades', 'Faturação', 'Peso'],
                  rows: @categories.values.sort_by { |r| [-r[:amount], r[:name]] }.map { |r| [r[:name], r[:quantity], money(r[:amount]), percentage(r[:amount])] } }
    zero = @venue.menu_items.where(archived_at: nil).where.not(id: @products.keys.grep(Integer)).order(:name).pluck(:name)
    sections << { title: 'Produtos atuais sem vendas no período', headers: ['Produto', 'Unidades'], rows: zero.map { |name| [name, 0] } } if zero.any?
    sections
  end

  def payment_sections
    methods = @payments.group_by(&:payment_method).map { |key, ps| [method_label(key), ps.sum(0.to_d, &:amount)] }.sort_by { |_, amount| -amount }
    table_rows = @tables.values.sort_by { |r| [-r[:amount], r[:name]] }
    range = effective_start.beginning_of_day...(@period.to + 1).beginning_of_day
    cancellations = @venue.orders.where(status: 'denied').where('COALESCE(orders.cancelled_at, orders.created_at) >= ? AND COALESCE(orders.cancelled_at, orders.created_at) < ?', range.begin, range.end)
    voids = @venue.payments.where(voided_at: range)
    [{ title: 'Métodos de pagamento', new_page: true, headers: ['Método', 'Recebido', 'Peso'], rows: methods.map { |name, amount| [name, money(amount), percentage(amount)] } + [['Total', money(@total), percentage(@total)]] },
     { title: 'Faturação e pedidos por mesa', headers: ['Mesa', 'Pedidos com pagamento', 'Faturação'], rows: table_rows.map { |r| [r[:name], r[:orders].size, money(r[:amount])] } },
     { title: 'Destaques das mesas', headers: ['Indicador', 'Resultado'], rows: [['Mesa com maior faturação', extreme(@tables, :amount, :max)], ['Mesa com menor faturação', extreme(@tables, :amount, :min)]] },
     { title: 'Anulações, cancelamentos e descontos', headers: ['Indicador', 'Resultado'], rows: [
       ['Pedidos cancelados / recusados', "#{cancellations.count} / #{money(cancellations.sum(:total))}"],
       ['Pagamentos anulados', "#{voids.count} / #{money(voids.sum(:amount))}"],
       ['Reduções de preço concedidas', money(@discounts)] ] }]
  end

  def time_sections
    rows = [1,2,3,4,5,6,0].map do |weekday|
      bins = TIME_BANDS.each_index.map { |bin| @weekday_hours[[weekday, bin]]&.dig(:amount) || 0.to_d }
      [WEEKDAYS[weekday], *bins.map { |v| money(v) }, money(bins.sum)]
    end
    [{ title: 'Dias e horários', new_page: true, headers: ['Dia', *TIME_BANDS.map { |first, last| format('%02d-%02dh', first, last) }, 'Total'], rows: rows },
     { title: 'Faturação e pedidos por hora', headers: ['Faixa horária', 'Pedidos com pagamento', 'Faturação'], rows: @hours.sort.map { |_, r| [r[:name], r[:orders].size, money(r[:amount])] } },
     { title: 'Consulta por dia e faixa horária', headers: ['Dia da semana', 'Faixa horária', 'Pedidos', 'Faturação'], rows: @weekday_hours.sort_by { |(day, bin), _| [(day + 6) % 7, bin] }.map { |(day, bin), r| [WEEKDAYS[day], format('%02dh - %02dh', *TIME_BANDS[bin]), r[:orders].size, money(r[:amount])] } }]
  end

  def product_label(row)
    row ? "#{row[:name]} / #{row[:quantity]} un. / #{money(row[:amount])}" : 'Sem dados'
  end

  def extreme(hash, metric, direction)
    rows = hash.values
    return 'Sem dados' if rows.empty?
    score = ->(r) { metric == :orders ? r[:orders].size : r[:amount] }
    target = rows.map(&score).public_send(direction)
    winners = rows.select { |r| score.call(r) == target }.map { |r| r[:name] }
    names = winners.first(3).join(', ')
    names += " (+#{winners.size - 3} empatados)" if winners.size > 3
    "#{names} / #{metric == :orders ? "#{target} pedidos" : money(target)}"
  end

  def hour_label(hour) = format('%02dh - %02dh', hour, hour + 1)
  def money(value) = ApplicationController.helpers.euros(value)
  def decimal(value) = format('%.1f', value).tr('.', ',')
  def percentage(value) = "#{decimal(@total.zero? ? 0 : value.to_d / @total * 100)}%"
  def change(current, previous) = previous.to_d.zero? ? 'Sem base' : "#{decimal((current.to_d - previous) / previous * 100)}%"
  def method_label(value) = ApplicationController.helpers.payment_method_label(value)
end
