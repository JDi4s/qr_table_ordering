class ReportPeriod
  class Invalid < StandardError; end
  VIEWS = %w[day last_7_days month year lifetime].freeze
  attr_reader :view, :from, :to, :comparison, :compare_from, :compare_to

  def initialize(params, today: Date.current)
    @today = today
    @view = VIEWS.include?(params[:view].to_s) ? params[:view].to_s : 'day'
    @from, @to = resolve_range(params)
    validate_range(@from, @to)
    @comparison = %w[previous none].include?(params[:compare].to_s) ? params[:compare].to_s : 'none'
    if @comparison == 'previous'
      days = (@to - @from).to_i + 1
      @compare_from, @compare_to = [@from - days, @from - 1]
    end
  end

  def comparing? = comparison == 'previous'

  def label
    case view
    when 'day' then from.strftime('%d/%m/%Y')
    when 'last_7_days' then 'Últimos 7 dias'
    when 'month' then from.strftime('%m/%Y')
    when 'year' then from.strftime('%Y')
    else 'Todo o período'
    end
  end

  def to_params
    { view: view, date: from.iso8601, month: from.strftime('%Y-%m'), year: from.year, compare: comparison }
  end

  private

  def resolve_range(params)
    case view
    when 'last_7_days'
      [@today - 6.days, @today]
    when 'month'
      month = parse_month(params[:month])
      [month.beginning_of_month, [month.end_of_month, @today].min]
    when 'year'
      year = Integer(params[:year].presence || @today.year)
      [Date.new(year, 1, 1), year == @today.year ? @today : Date.new(year, 12, 31)]
    when 'lifetime'
      [Date.new(1900, 1, 1), @today]
    else
      date = parse_date(params[:date].presence || @today.iso8601)
      [date, date]
    end
  rescue ArgumentError
    raise Invalid, 'Escolha um período válido.'
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise Invalid, 'Escolha uma data válida.'
  end

  def parse_month(value)
    Date.strptime(value.to_s, '%Y-%m')
  rescue ArgumentError
    raise Invalid, 'Escolha um mês válido.'
  end

  def validate_range(first, last)
    raise Invalid, 'O período escolhido ainda não terminou.' if first > @today
    raise Invalid, 'Indique datas entre os anos 1900 e 9999.' unless first.year >= 1900 && last.year <= 9999
    raise Invalid, 'O período escolhido não é válido.' if last < first
  end
end
