require 'application_system_test_case'

class SupportLiveSystemTest < ApplicationSystemTestCase
  test 'support and manager exchange live messages without losing a draft' do
    venue, = build_venue
    manager = venue_user(venue)
    owner = User.create!(email: "browser-support-#{SecureRandom.hex(4)}@example.com", password: 'Test-password-123', role: 'platform_admin')
    ticket = venue.support_tickets.create!(created_by: manager, subject: 'Conversa em direto', category: 'menu')

    Capybara.using_session(:support_manager) do
      browser_sign_in(manager)
      visit staff_support_ticket_path(ticket)
      assert_selector 'turbo-cable-stream-source[data-scope="ticket"][connected]', visible: :all, wait: 10
      assert_selector 'turbo-cable-stream-source[data-scope="notifications"][connected]', visible: :all, wait: 10
      fill_in 'Responder', with: 'Rascunho ainda por enviar'
    end

    Capybara.using_session(:support_admin) do
      browser_sign_in(owner)
      visit admin_support_ticket_path(ticket)
      assert_selector 'turbo-cable-stream-source[data-scope="ticket"][connected]', visible: :all, wait: 10
      fill_in 'Responder como Suporte', with: 'Resposta instantânea do suporte'
      submit_and_wait_for_navigation('Enviar resposta')
      assert_text 'Resposta enviada'
      assert_selector 'turbo-cable-stream-source[data-scope="ticket"][connected]', visible: :all, wait: 10
    end

    Capybara.using_session(:support_manager) do
      within("#support_ticket_messages_#{ticket.id}") { assert_text 'Resposta instantânea do suporte' }
      assert_field 'Responder', with: 'Rascunho ainda por enviar'
      within('#support_notifications') { assert_text 'Resposta do Suporte' }
      submit_and_wait_for_navigation('Enviar mensagem')
      assert_text 'Mensagem enviada'
      assert_selector 'turbo-cable-stream-source[data-scope="ticket"][connected]', visible: :all, wait: 10
    end

    Capybara.using_session(:support_admin) do
      within("#support_ticket_messages_#{ticket.id}") { assert_text 'Rascunho ainda por enviar' }
      select 'Resolvido', from: 'Estado'
      submit_and_wait_for_navigation('Guardar estado')
      assert_text 'Ticket atualizado'
      assert_selector 'turbo-cable-stream-source[data-scope="ticket"][connected]', visible: :all, wait: 10
    end

    Capybara.using_session(:support_manager) do
      assert_selector "#support_ticket_status_#{ticket.id}", text: 'Resolvido'
      assert_text 'Este pedido está resolvido'
      assert_no_field 'Responder'
      page.save_screenshot(Rails.root.join('tmp/screenshots/support-live.png'))
    end

    Capybara.using_session(:support_admin) do
      select 'Em análise', from: 'Estado'
      submit_and_wait_for_navigation('Guardar estado')
      assert_text 'Ticket atualizado'
      assert_selector 'turbo-cable-stream-source[data-scope="ticket"][connected]', visible: :all, wait: 10
    end

    Capybara.using_session(:support_manager) do
      assert_field 'Responder'
      fill_in 'Responder', with: 'Mensagem após reabertura em direto'
      submit_and_wait_for_navigation('Enviar mensagem')
      assert_text 'Mensagem enviada'
    end

    Capybara.using_session(:support_admin) do
      within("#support_ticket_messages_#{ticket.id}") { assert_text 'Mensagem após reabertura em direto' }
    end
  end

  private

  def submit_and_wait_for_navigation(label)
    # Repeated flash text and a connected source from the old page must not
    # count as completion of the next Turbo visit.
    page.execute_script("document.body.setAttribute('data-system-navigation-checkpoint', 'waiting')")
    click_on label
    assert_selector 'body:not([data-system-navigation-checkpoint])'
    assert_selector 'turbo-cable-stream-source[data-scope="ticket"][connected]', visible: :all, wait: 10
  end

  def browser_sign_in(user)
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Palavra-passe', with: 'Test-password-123'
    click_on 'Entrar'
    assert_no_button 'Entrar'
  end
end
