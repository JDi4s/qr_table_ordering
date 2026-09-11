require 'test_helper'

class ReportPeriodTest < ActiveSupport::TestCase
  test 'last seven days is a rolling period ending today' do
    period = ReportPeriod.new({ view: 'last_7_days' }, today: Date.new(2026, 9, 11))

    assert_equal Date.new(2026, 9, 5), period.from
    assert_equal Date.new(2026, 9, 11), period.to
    assert_equal 'Últimos 7 dias', period.label
  end
end
