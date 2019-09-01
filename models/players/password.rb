module Players
  module Password

    def password_matches?(pass)
      encrypt_password(pass, self.password_salt) == password_hash
    end

    def set_password(pass)
      salt = Digest::SHA1.hexdigest([Time.now, rand].join)
      hash = encrypt_password(pass, salt)
      update password_salt: salt, password_hash: hash do
        yield if block_given?
      end
    end

    def encrypt_password(pass, salt)
      Digest::SHA1.hexdigest([pass, salt].join)
    end

  end
end
