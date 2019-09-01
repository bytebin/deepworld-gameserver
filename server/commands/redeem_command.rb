class RedeemCommand < BaseCommand
  data_fields :code
  throttle 1, 1.0, true

  def execute
    case code.try(:[],0)
    when 'a'
      redeem_access_code
    when 'z'
      ZoneEntryCommand.new([code], player.connection).execute!
    else
      redeem_redemption_code
    end
  end

  def redeem_access_code
    if player.premium
      @errors << "You are already a premium player"
      failure!
    else

      AccessCode.find_one({ code: code }) do |access_code|
        if access_code
          if access_code.available?
            access_code.redeem! do
              player.convert_premium!
            end
          else
            @errors << "Access code has been used"
          end
        else
          @errors << "Access code not found"
        end

        failure! if @errors.present?
      end
    end
  end

  def redeem_redemption_code
    RedemptionCode.find_one({ code: code }) do |redemption|
      if redemption.nil?
        @errors << "Redemption code not found"
      elsif !redemption.available? || redemption.redeemed_by?(player.id)
        @errors << "Redemption code has been used"
      elsif redemption.premium && !player.premium
        @errors << "Sorry, this code can only be used by premium players."
      else
        redemption.redeem!(player)
      end

      failure! if @errors.present?
    end
  end

  def fail
    alert @errors.first
  end
end