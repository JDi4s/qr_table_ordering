class ProductionArea < ApplicationRecord
  belongs_to :establishment
  validates :preparation_key, inclusion: { in: MenuItem::PREPARATION_KEYS.keys }
  has_many :preparation_tasks, dependent: :nullify
  has_many :menu_items, dependent: :nullify
  has_many :production_area_users, dependent: :destroy
  has_many :users, through: :production_area_users

  validates :name, presence: true, uniqueness: { scope: :establishment_id, case_sensitive: false }
end
