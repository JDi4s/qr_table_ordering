class Admin::MenuImportsController < Admin::BaseController
  before_action :load_destination

  def new
    @sources = Establishment.where.not(id: @destination.id).joins(:menu_items).where(menu_items: { archived_at: nil }).distinct.order(:name)
    selection = Rails.application.message_verifier(:menu_import).verified(params[:quote].to_s)&.symbolize_keys if params[:quote].present?
    if selection && selection[:destination_id] == @destination.id
      params[:source_id] = selection[:source_id]
    else
      selection = nil
    end
    if params[:source_id].present?
      @source = @sources.find(params[:source_id])
      @plan = MenuImport.new(source: @source, destination: @destination, **(selection || {}).slice(:category_ids, :product_ids))
    end
  rescue MenuImport::Invalid => error
    redirect_to admin_establishments_path, alert: error.message
  end

  def review
    @source = Establishment.find(params[:source_id])
    @plan = MenuImport.new(source: @source, destination: @destination, category_ids: params[:category_ids] || [], product_ids: params[:product_ids] || [])
    raise MenuImport::Invalid, 'Seleciona pelo menos uma categoria ou produto.' if @plan.selected_categories.empty?
    @quote = Rails.application.message_verifier(:menu_import).generate({ source_id: @source.id, destination_id: @destination.id,
      category_ids: @plan.selected_categories.map(&:id), product_ids: @plan.selected_products.map(&:id), digest: @plan.digest }, expires_in: 15.minutes)
  rescue MenuImport::Invalid => error
    redirect_to new_admin_establishment_menu_import_path(@destination, source_id: params[:source_id]), alert: error.message, status: :see_other
  end

  def create
    quote = Rails.application.message_verifier(:menu_import).verified(params[:quote].to_s)&.symbolize_keys
    raise MenuImport::Invalid, 'A revisão expirou. Escolhe novamente o menu.' unless quote && quote[:destination_id] == @destination.id
    result = MenuImport.copy!(**quote.slice(:source_id, :destination_id, :category_ids, :product_ids), expected_digest: quote[:digest], user: current_user)
    redirect_to admin_establishments_path, notice: "Menu importado para #{@destination.name}: #{result[:products]} produtos e #{result[:photos]} fotografias.", status: :see_other
  rescue MenuImport::Invalid => error
    redirect_to new_admin_establishment_menu_import_path(@destination), alert: error.message, status: :see_other
  end

  private

  def load_destination
    @destination = Establishment.find(params[:establishment_id])
    redirect_to admin_establishments_path, alert: 'Este estabelecimento já tem menu.', status: :see_other unless @destination.menu_empty?
  end
end
