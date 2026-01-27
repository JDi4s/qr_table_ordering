class User < ApplicationRecord
  has_secure_password

  enum role: { staff: "staff", admin: "admin" }
  validates :email, presence: true, uniqueness: true
end
