class Establishment < ApplicationRecord
  has_one_attached :logo
  has_many :scheduled_menus, class_name: 'LunchMenu', dependent: :destroy
  has_one :lunch_menu, -> { where(menu_kind: 'lunch') }, class_name: 'LunchMenu'
  has_one :breakfast_menu, -> { where(menu_kind: 'breakfast') }, class_name: 'LunchMenu'
  has_many :service_zones, dependent: :destroy

  has_many :tables, dependent: :restrict_with_error
  has_many :categories, dependent: :restrict_with_error
  has_many :menu_items, through: :categories
  has_many :users, dependent: :restrict_with_error
  has_many :orders, through: :tables
  has_many :payments, through: :orders
  has_many :service_calls, through: :tables
  has_many :production_areas, dependent: :destroy
  has_many :audit_events, dependent: :destroy
  has_many :cash_closures, dependent: :destroy
  has_many :support_tickets, dependent: :restrict_with_error
  has_many :support_sessions, dependent: :restrict_with_error
  has_many :google_review_clicks, dependent: :delete_all
  belongs_to :service_paused_by_user, class_name: 'User', optional: true
  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :table_limit, :monthly_fee_cents, :production_areas_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :plan, inclusion: { in: %w[essential management] }
  validate :logo_must_be_an_accepted_image
  validate :limit_covers_active_tables
  validate :limit_covers_preparation_areas
  validate :google_review_url_must_be_safe
  before_validation { self.google_review_url = google_review_url.to_s.strip.presence }

  def menu_empty?
    !categories.exists? && !scheduled_menus.exists?
  end

  def google_reviews_available?
    google_reviews_enabled? && google_review_url.present?
  end

  def monthly_fee
    monthly_fee_cents.to_d / 100
  end

  def monthly_fee=(value)
    raw = value.to_s.tr(',', '.')
    self.monthly_fee_cents = raw.match?(/\A\d+(?:\.\d{1,2})?\z/) ? (BigDecimal(raw) * 100).to_i : nil
  rescue ArgumentError
    self.monthly_fee_cents = nil
  end

  def staff_stream
    "establishment_#{id}_staff"
  end

  def production_areas_enabled?
    production_areas_limit.to_i.positive?
  end

  def essential_plan?
    plan == 'essential'
  end

  def management_plan?
    plan == 'management'
  end

  def pause_service!(user)
    with_lock do
      update!(accepting_orders: false, service_paused_at: Time.current, service_paused_by_user: user)
    end
  end

  def open_service!
    with_lock do
      update!(accepting_orders: true, service_paused_at: nil, service_paused_by_user: nil)
    end
  end

  def available_production_areas
    scope = production_areas.where(active: true).order(:position, :name)
    production_areas.where(id: scope.limit(production_areas_limit).select(:id)).order(:position, :name)
  end

  def ensure_default_production_areas!
    return if production_areas.exists?
    %w[Balcão Cozinha].first(production_areas_limit.to_i).each_with_index do |name, index|
      production_areas.find_or_create_by!(name: name) { |area| area.position = index; area.preparation_key = index.zero? ? 'counter' : 'kitchen' }
    end
  end

  private

  def limit_covers_preparation_areas
    return unless persisted? && production_areas_limit_changed? && production_areas_limit
    if production_areas_limit.positive? && production_areas_limit < production_areas.where(active: true).count
      errors.add(:production_areas_limit, 'não pode ser inferior ao número de áreas ativas. Desativa primeiro as áreas que já não usas.')
    elsif production_areas_limit.zero? && service_division_enabled?
      errors.add(:production_areas_limit, 'desliga primeiro a divisão por áreas nas definições do estabelecimento.')
    end
  end

  def google_review_url_must_be_safe
    return if google_review_url.blank?

    uri = URI.parse(google_review_url)
    hosts = %w[google.com www.google.com search.google.com maps.google.com google.pt www.google.pt g.page maps.app.goo.gl goo.gl]
    unless uri.is_a?(URI::HTTPS) && hosts.include?(uri.host) && uri.userinfo.nil? && uri.port == 443 && google_review_url.length <= 2048
      errors.add(:google_review_url, 'deve ser uma ligação HTTPS de avaliações do Google')
    end
  rescue URI::InvalidURIError
    errors.add(:google_review_url, 'deve ser uma ligação HTTPS de avaliações do Google')
  end

  def logo_must_be_an_accepted_image
    return unless logo.attached?

    unless logo.content_type.in?(%w[image/png image/jpeg image/webp])
      errors.add(:logo, 'deve ser PNG, JPG ou WebP')
    end

    errors.add(:logo, 'não pode ultrapassar 5 MB') if logo.byte_size > 5.megabytes
  end

  def limit_covers_active_tables
    if persisted? && table_limit && table_limit < tables.where(active: true).count
      errors.add(:table_limit, 'não pode ser inferior ao número de mesas ativas')
    end
  end
end
