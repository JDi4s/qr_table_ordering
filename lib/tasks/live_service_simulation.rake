namespace :simulation do
  desc 'Run a live service simulation exclusively against Café Teste'
  task live_service: :environment do
    establishment = Establishment.find_by(slug: 'cafe-teste')
    raise 'Não foi encontrado o estabelecimento Café Teste (slug: cafe-teste).' unless establishment

    LiveServiceSimulator.new(
      establishment: establishment,
      events: ENV.fetch('EVENTS', LiveServiceSimulator::DEFAULT_EVENTS),
      interval_seconds: ENV.fetch('INTERVAL_SECONDS', LiveServiceSimulator::DEFAULT_INTERVAL_SECONDS),
      final_wait_seconds: ENV.fetch('FINAL_WAIT_SECONDS', LiveServiceSimulator::DEFAULT_FINAL_WAIT_SECONDS)
    ).run!
  end
end
