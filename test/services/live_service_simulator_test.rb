require 'test_helper'

class LiveServiceSimulatorTest < ActiveSupport::TestCase
  class NoSleep
    def self.sleep(_seconds); end
  end

  setup do
    @venue, @table, @product = build_venue('cafe-teste')
    @second_table = @venue.tables.create!(number: 2)
    @product.category.menu_items.create!(name: 'Água', price: 1, available: true)
    @product.category.menu_items.create!(name: 'Café', price: 0.85, available: true)
    @output = StringIO.new
  end

  test 'creates visible live orders and service calls without completing them automatically' do
    simulator = LiveServiceSimulator.new(
      establishment: @venue,
      events: 3,
      interval_seconds: 0,
      final_wait_seconds: 0,
      output: @output,
      sleeper: NoSleep,
      random: Random.new(1)
    )

    assert_difference -> { @venue.orders.count }, 2 do
      assert_difference -> { @venue.service_calls.count }, 1 do
        simulator.run!
      end
    end

    assert @venue.orders.all?(&:pending?)
    assert @venue.orders.all? { |order| order.note.start_with?('[ENSAIO ') }
    assert @venue.orders.all? { |order| order.customer_token.start_with?('ensaio-') }
    assert_includes @output.string, 'PEDIDO #'
    assert_includes @output.string, 'CHAMADA #'
    assert_includes @output.string, 'RESULTADO: ATENÇÃO'
  end

  test 'refuses to run against a real establishment' do
    other_venue, = build_venue('cliente-real')
    simulator = LiveServiceSimulator.new(
      establishment: other_venue,
      events: 1,
      interval_seconds: 0,
      final_wait_seconds: 0,
      output: @output,
      sleeper: NoSleep
    )

    error = assert_raises(ArgumentError) { simulator.run! }
    assert_equal 'Este ensaio só pode ser executado no Café Teste.', error.message
  end
end
