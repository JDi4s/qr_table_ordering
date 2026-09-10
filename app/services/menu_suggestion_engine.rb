class MenuSuggestionEngine
  GROUP_RULES = {
    coffee: %i[pastry],
    pastry: %i[coffee],
    beer: %i[snack sandwich],
    wine: %i[snack sandwich],
    spirits: %i[snack],
    sandwich: %i[coffee water juice],
    snack: %i[beer wine sandwich],
    juice: %i[pastry sandwich],
    water: %i[coffee juice]
  }.freeze

  def self.call(source_items:, scope:, limit: 4)
    new(source_items: source_items, scope: scope, limit: limit).call
  end

  def initialize(source_items:, scope:, limit: 4)
    @source_items = Array(source_items)
    @scope = scope
    @limit = limit
  end

  def call
    source_groups = @source_items.map { |item| group_for(item) }.compact.uniq
    wanted_groups = source_groups.flat_map { |group| GROUP_RULES.fetch(group, []) }.uniq
    return [] if wanted_groups.empty?

    candidates = @scope.includes(category: :parent).where.not(id: @source_items.map(&:id)).to_a
    candidates
      .filter_map do |candidate|
        group = group_for(candidate)
        next unless wanted_groups.include?(group)

        [candidate, wanted_groups.index(group)]
      end
      .sort_by { |candidate, priority| [priority, candidate.name.downcase] }
      .first(@limit)
      .map(&:first)
  end

  def self.group_for(item)
    new(source_items: [], scope: MenuItem.none).group_for(item)
  end

  private

  def group_for(item)
    names = category_names(item.category)
    text = normalize([item.name, item.description, *names].compact.join(' '))

    return :coffee if text.match?(/cafe|descafeinado|gal[aã]o|meia de leite|ch[aá]|infus[aã]o|chocolate quente|cafetaria/)
    return :pastry if text.match?(/pastelaria|croissant|nata|queque|muffin|bolo|tarte|pudim|palmier|eclair|jesuita/)
    return :sandwich if text.match?(/sandes|tosta|baguete|prego|p[aã]o com|misto|fiambre|presunto|atum|frango/)
    return :beer if text.match?(/cerveja|fino|caneca|panache|radler/)
    return :wine if text.match?(/vinho|sangria|espumante/)
    return :spirits if text.match?(/bebidas brancas|whisky|vodka|gin|rum|brandy|aguardente|tequila|licor|martini|baileys|j[aä]ger|mojito|margarita|aperol|caipir/)
    return :snack if text.match?(/snack|petisco|amendoim|batata frita/)
    return :juice if text.match?(/sumo|limonada|ice tea/)
    return :water if text.match?(/agua|[áa]gua|t[oó]nica/)

    nil
  end

  def category_names(category)
    names = []
    current = category
    while current
      names << current.name
      current = current.parent
    end
    names
  end

  def normalize(value)
    ActiveSupport::Inflector.transliterate(value).downcase
  end
end
