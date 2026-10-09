class ServiceZone < ApplicationRecord
  belongs_to :establishment
  has_many :tables, dependent: :nullify
  validates :name, presence: true, length: { maximum: 80 }, uniqueness: { scope: :establishment_id }
  validate :routing_belongs_to_venue

  def destination(key)
    establishment.production_areas.where(active: true).find_by(id: routing[key].to_i)
  end

  private

  def routing_belongs_to_venue
    unless routing.is_a?(Hash) && routing.size <= 20 && routing.values.all? { |id| id.blank? || establishment.production_areas.where(active: true).exists?(id: id) }
      errors.add(:routing, 'seleciona postos deste estabelecimento')
    end
  end
end
