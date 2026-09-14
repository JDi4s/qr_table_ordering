class Staff::SettingsController < Staff::BaseController
  def edit; end

  def service_status
    head :forbidden and return unless current_user.manager?

    accepting_orders = params[:accepting_orders].to_s == '1'
    if accepting_orders
      current_establishment.open_service!
      action = 'service_opened'
      notice = 'Serviço aberto. Os clientes já podem enviar pedidos e chamadas.'
    else
      current_establishment.pause_service!(current_user)
      action = 'service_paused'
      notice = 'Serviço pausado. O menu continua visível, mas novos pedidos e chamadas estão bloqueados.'
    end
    AuditLogger.record(user: current_user, action: action, record: current_establishment)
    redirect_to edit_staff_settings_path, notice: notice, status: :see_other
  end

  def update
    save_establishment_settings if manager_access? && params[:establishment].present?

    if params.dig(:user, :staff_sound_enabled).present?
      current_user.update!(staff_sound_enabled: params.dig(:user, :staff_sound_enabled) == '1')
    end
    password = params.dig(:user, :password).to_s
    if password.present?
      current_user.update!(password: password, must_change_password: false)
    end
    redirect_to edit_staff_settings_path, notice: 'Preferências guardadas.', status: :see_other
  end

  private

  def establishment_params
    params.require(:establishment).permit(:logo)
  end

  def save_establishment_settings
    logo = establishment_params[:logo]
    if logo.present?
      current_establishment.update!(logo: logo)
      AuditLogger.record(user: current_user, action: 'branding_updated', record: current_establishment)
    end
  end
end
