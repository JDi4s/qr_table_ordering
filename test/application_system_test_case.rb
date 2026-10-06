require 'test_helper'
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 900]

  setup do
    # The browser is shared across tests; mobile scenarios must not change the
    # viewport expected by the next desktop scenario.
    page.current_window.resize_to(1280, 900)
  end
end
