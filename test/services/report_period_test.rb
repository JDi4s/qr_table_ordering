require 'test_helper'

class ReportPeriodTest < ActiveSupport::TestCase
  test 'custom dates survive links and reject future reversed or invalid dates' do
    period = ReportPeriod.new({ view: 'custom', from: '2026-10-01', to: '2026-10-03' }, today: Date.new(2026, 10, 6))
    assert_equal '01/10/2026 - 03/10/2026', period.label
    assert_equal '2026-10-03', period.to_params[:to]
    assert_equal period.from, ReportPeriod.new(period.to_params, today: Date.new(2026, 10, 6)).from
    [['2026-10-03','2026-10-01'], ['2026-10-01','2026-10-07'], ['bad','2026-10-03']].each do |first, last|
      assert_raises(ReportPeriod::Invalid) { ReportPeriod.new({ view: 'custom', from: first, to: last }, today: Date.new(2026, 10, 6)) }
    end
  end

  test 'last seven days is a rolling period ending today' do
    period = ReportPeriod.new({ view: 'last_7_days' }, today: Date.new(2026, 9, 11))

    assert_equal Date.new(2026, 9, 5), period.from
    assert_equal Date.new(2026, 9, 11), period.to
    assert_equal 'Últimos 7 dias', period.label
  end
end
