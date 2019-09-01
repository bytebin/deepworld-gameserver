require 'spec_helper'
include BlockHelpers

describe ChangeAppearanceCommand do

  pending 'should test this command' do
  end

end



# describe 'appearance' do

#       before(:each) do
#         @hair = 1405
#         @non_base_hair = Game.item_code('hair/beard-seneca')
#         @facialhair = 1431

#         Game.config.entities.avatar.options['skin-color'] = %w{red blue}
#         Game.config.entities.avatar.options['hair-color'] = %w{green yellow}

#         Message.new(:block_place, [3, 4, FRONT, 773, 0]).send(@o_sock)
#         reactor_wait
#       end

#       it 'should update appearance via dialog' do
#         cmd = BlockUseCommand.new([3, 4, FRONT, ['red', 'yellow', @hair, @facialhair]], @one.connection)
#         cmd.execute!
#         cmd.errors.should == []

#         msg = Message.receive_one(@t_sock, only: :entity_status)
#         msg.should_not be_blank
#         appearance = msg.data.first[4]
#         appearance['c*'].should == 'red'
#         appearance['h*'].should == 'yellow'
#         appearance['h'].should == @hair
#         appearance['fh'].should == @facialhair
#       end

#       it 'should not update appearance with invalid inputs via dialog' do
#         cmd = BlockUseCommand.new([3, 4, FRONT, [123, 123, 123, 123]], @one.connection)
#         cmd.execute!
#         cmd.errors.should_not == []
#       end

#       it 'should not update appearance with invalid colors' do
#         cmd = BlockUseCommand.new([3, 4, FRONT, ['purple', 'orange', @hair, @facialhair]], @one.connection)
#         cmd.execute!
#         cmd.errors.should_not == []
#       end

#       it 'should not update appearance if item is not "base" and player does not have it in wardrobe' do
#         cmd = BlockUseCommand.new([3, 4, FRONT, ['red', 'green', @non_base_hair, @facialhair]], @one.connection)
#         cmd.execute!
#         cmd.errors.should_not == []
#       end

#       it 'should update appearance if item is not "base" but player has it in wardrobe' do
#         @one.wardrobe = [@non_base_hair]
#         cmd = BlockUseCommand.new([3, 4, FRONT, ['red', 'green', @non_base_hair, @facialhair]], @one.connection)
#         cmd.execute!
#         cmd.errors.should_not == []
#       end

#     end