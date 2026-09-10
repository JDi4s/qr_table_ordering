class ProductionAreaUser < ApplicationRecord
  self.table_name = 'production_area_users'

  belongs_to :production_area
  belongs_to :user
end
