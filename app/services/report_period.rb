class ReportPeriod
  class Invalid < StandardError; end

  attr_reader :period, :from, :to, :comparison, :compare_from, :compare_to, :group

  def initialize(params, today: Date.current)
    @period = %w[today week month year custom].include?(params[:period]) ? params[:period] : 'today'
    @from, @to = case period
    when 'week' then [today - 6, today]
    when 'month' then [today.beginning_of_month, today]
    when 'year' then [today.beginning_of_year, today]
    when 'custom' then [parse(params[:from]), parse(params[:to])]
    else [today, today]
    end
    validate_range(from, to)
    @comparison = %w[previous custom none].include?(params[:compare]) ? params[:compare] : 'previous'
    unless comparison == 'none'
      days = (to - from).to_i + 1
      @compare_from, @compare_to = comparison == 'custom' ?
        [parse(params[:compare_from]), parse(params[:compare_to])] : [from - days, from - 1]
      validate_range(compare_from, compare_to)
    end
    default_group = from == to ? 'hour' : ((to - from).to_i > 62 ? 'month' : 'day')
    @group = %w[hour day month].include?(params[:group]) ? params[:group] : default_group
  end

  def comparing?
    comparison != 'none'
  end

  def to_params
    { period: period, from: from.iso8601, to: to.iso8601, compare: comparison,
      compare_from: compare_from&.iso8601, compare_to: compare_to&.iso8601, group: group }
  end

  private

  def parse(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise Invalid, 'Preencha as datas de início e fim do intervalo.'
  end

  def validate_range(first, last)
    raise Invalid, 'A data final deve ser igual ou posterior à inicial.' if last < first
    raise Invalid, 'Indique datas entre os anos 1900 e 9999.' unless first.year >= 1900 && last.year <= 9999
  end
end
