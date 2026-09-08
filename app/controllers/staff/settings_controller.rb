class Staff::SettingsController < Staff::BaseController
  def edit; end

  def update
    current_user.update!(staff_sound_enabled: params.dig(:user, :staff_sound_enabled) == '1')
    redirect_to edit_staff_settings_path, notice: 'Preferências guardadas.', status: :see_other
  end
end
