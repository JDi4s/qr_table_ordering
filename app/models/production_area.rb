class ProductionArea < ApplicationRecord
  belongs_to :establishment
  has_many :menu_items, dependent: :nullify
  has_many :production_area_users, dependent: :destroy
  has_many :users, through: :production_area_users

  validates :name, presence: true, uniqueness: { scope: :establishment_id, case_sensitive: false }
end
