class GoogleReviewStatistics
  attr_reader :started_at

  def initialize(establishment:, from:, to:)
    @venue, @from, @to = establishment, from, to
    @started_at = establishment.google_review_tracking_started_at.in_time_zone
  end

  def available? = @to.end_of_day >= started_at

  def rows
    [['Cliques em Avaliar no Google', available? ? clicks.count : 'Sem registo'],
     ['Navegadores distintos que clicaram', available? ? clicks.distinct.count(:visitor_digest) : 'Sem registo']]
  end

  def note
    "Registo desde #{started_at.strftime('%d/%m/%Y %H:%M')}. Não confirma avaliações publicadas no Google. " \
      'Navegadores distintos são identificados pela sessão; limpar os cookies ou usar outro navegador pode contar novamente. ' \
      'Valores do estabelecimento inteiro, sem filtro por funcionário.'
  end

  def section
    { title: 'Avaliações Google', headers: ['Indicador', 'Resultado'], rows: rows }
  end

  private

  def clicks
    @clicks ||= @venue.google_review_clicks.where(created_at: @from.beginning_of_day...(@to + 1).beginning_of_day)
  end
end
