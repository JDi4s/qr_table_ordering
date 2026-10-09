class PreserveExistingServiceAreaPermissions < ActiveRecord::Migration[7.1]
  def up
    # Preserve venues already using the previous unrestricted division. From this
    # point onwards the Administration limit is enforced for every new area.
    execute <<~SQL
      UPDATE establishments SET production_areas_limit = GREATEST(2,
        (SELECT COUNT(*) FROM production_areas WHERE production_areas.establishment_id = establishments.id AND active = TRUE))
      WHERE service_division_enabled = TRUE AND production_areas_limit < GREATEST(2,
        (SELECT COUNT(*) FROM production_areas WHERE production_areas.establishment_id = establishments.id AND active = TRUE))
    SQL
  end
  def down
    # Permissions may have subsequently been changed by the administrator.
  end
end
