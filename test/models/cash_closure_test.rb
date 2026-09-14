require 'test_helper'

class CashClosureTest < ActiveSupport::TestCase
  setup do
    @venue, = build_venue
    @manager = venue_user(@venue, role: 'manager')
  end

  test 'reopening preserves the old closure and allows a new active closure for the same day' do
    closure = @venue.cash_closures.create!(
      user: @manager, business_date: Date.current, total_amount: 20,
      payments_count: 1, payment_breakdown: { cash: '20' }, closed_at: Time.current
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      @venue.cash_closures.create!(user: @manager, business_date: Date.current, total_amount: 20,
                                   payments_count: 1, payment_breakdown: {}, closed_at: Time.current)
    end

    closure.reopen!(@manager, reason: 'Corrigir método de pagamento')
    replacement = @venue.cash_closures.create!(
      user: @manager, business_date: Date.current, total_amount: 20,
      payments_count: 1, payment_breakdown: { card: '20' }, closed_at: Time.current
    )

    assert closure.reload.reopened?
    assert_equal 'Corrigir método de pagamento', closure.reopen_reason
    assert_equal @manager, closure.reopened_by_user
    assert_equal replacement, @venue.cash_closures.active.find_by!(business_date: Date.current)
    assert_equal 2, @venue.cash_closures.where(business_date: Date.current).count
  end

  test 'staff cannot reopen cash' do
    staff = venue_user(@venue, role: 'staff')
    closure = @venue.cash_closures.create!(
      user: @manager, business_date: Date.current, total_amount: 0,
      payments_count: 0, payment_breakdown: {}, closed_at: Time.current
    )

    assert_raises(Order::InvalidTransition) { closure.reopen!(staff, reason: 'Sem autorização') }
    assert_not closure.reload.reopened?
  end
end
