namespace :setup do
  desc 'Create the platform owner without putting a password in shell history'
  task platform_admin: :environment do
    require 'io/console'
    print 'Email do administrador: '
    email = $stdin.gets.to_s.strip.downcase
    print 'Palavra-passe (mínimo 12 caracteres): '
    password = $stdin.noecho(&:gets).to_s.chomp
    puts
    raise 'Já existe uma conta com este email.' if User.exists?(email: email)
    User.create!(name: 'João Dias', email: email, password: password, role: 'platform_admin')
    puts 'Administrador criado.'
  end

  desc 'Promote an existing venue user to manager (choose email interactively)'
  task manager: :environment do
    print 'Email do utilizador existente: '
    user = User.find_by!(email: $stdin.gets.to_s.strip.downcase)
    raise 'A conta não pertence a um estabelecimento.' unless user.establishment_id
    user.update!(role: 'manager')
    puts 'Gerente atualizado.'
  end
end
