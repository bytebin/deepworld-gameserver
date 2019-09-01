require 'spec_helper'

describe ChangePasswordCommand do

  # Password 'password'
  SALT = '0b2ac117e53c44d92e7bef121eddeaa19a080c98'
  HASH = '051484c98978c0cf97c3f60926eb6c73f65f0a86'

  before(:each) do
    with_a_zone
    with_a_player(@zone, password_salt: SALT, password_hash: HASH)
  end

  it 'should allow a password change' do
    command! @one, :change_password, ['password', 'new_password']
    eventually do
      receive_msg!(@one, :notification).data.to_s.should =~ /password has been updated/
      @one.password_matches?('new_password').should be_true
    end
  end

  it 'should deny a password change if old password does not match' do
    command(@one, :change_password, ['bad_password', 'new_password']).should_not be_valid
    receive_msg!(@one, :notification).data.to_s.should =~ /old password/
  end

  it 'should deny a password change if new password is invalid' do
    command(@one, :change_password, ['password', 'a']).should_not be_valid
    receive_msg!(@one, :notification).data.to_s.should =~ /must be between/
  end

end