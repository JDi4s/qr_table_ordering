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
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.join(', ')
    render :edit, status: :unprocessable_entity
  end

  private

  def establishment_params
    permitted = [:logo]
    permitted << :google_review_url if current_establishment.google_reviews_enabled?
    params.require(:establishment).permit(*permitted)
  end

  def save_establishment_settings
    current_establishment.with_lock do
      attributes = establishment_params.to_h
      attributes.delete('logo') if attributes['logo'].blank?
      return if attributes.empty?

      current_establishment.update!(attributes)
      if attributes.key?('logo')
        AuditLogger.record(user: current_user, action: 'branding_updated', record: current_establishment)
      end
      if attributes.key?('google_review_url')
        AuditLogger.record(user: current_user, action: 'google_review_settings_updated', record: current_establishment)
      end
    end
  end
end
