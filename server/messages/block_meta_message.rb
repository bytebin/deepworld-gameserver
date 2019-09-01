# Meta information for certain kinds of blocks (dishes, etc.)
class BlockMetaMessage < BaseMessage
  configure collection: true
  data_fields :x, :y, :metadata
end