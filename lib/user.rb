require 'pg'
require 'bcrypt'
require_relative 'database_connection'

class User
  attr_reader :user_id, :username, :email

  def initialize(user_id:, username:, email:)
    @user_id = user_id.to_i
    @username = username
    @email = email
  end

  def self.create(username:, password:, email:)
    return false unless User.valid_username?(username: username)
    # return false if password too short
    # return false if email invalid or not unique
    encrypted_password = BCrypt::Password.create(password)
    result = DatabaseConnection.query("INSERT INTO users (username, password, email)
                              VALUES ('#{username.downcase}', '#{encrypted_password}', '#{email.downcase}')
                              RETURNING id, username, email;")
    User.new(user_id: result[0]["id"], username: result[0]["username"], email: result[0]["email"])
  end

  def self.find(user_id:) # this will cause an error if id not in database
    user_info = DatabaseConnection.query("SELECT * FROM users
                                 WHERE id = #{user_id};")[0]
    User.new(user_id: user_info["id"], username: user_info["username"], email: user_info["email"])
  end

  def self.authenticate(email:, password:)
    user_info = DatabaseConnection.query("SELECT * FROM users
                                 WHERE email = '#{email.downcase}';")
    return false unless user_info.cmd_tuples > 0 # nb that cmd_tuples is a pg object attribute for the number of database lines returned
    return false unless BCrypt::Password.new(user_info[0]["password"]) == password # nb might cause a problem if email's not unique
    User.new(user_id: user_info[0]["id"], username: user_info[0]["username"], email: email)
  end

  private
  def self.valid_username?(username:)
    return false if username.length < 5
    return false if !!(username =~ /[@€!£#$%^&*']/)
    return false if ((DatabaseConnection.query("SELECT username FROM users;")).map{|e| e["username"].downcase}).include?(username.downcase)
    true
  end

end
