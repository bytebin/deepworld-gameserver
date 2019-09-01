module Zones
  module Persistence

    def load_local!
      local_path = Deepworld::Env.test? ? data_path : "tmp/#{data_path}"
      if File.exists?(local_path)
        load_binary File.read(local_path)
      else
        raise "Cannot find zone file #{local_path}"
      end
    end

    def load_s3!
      Game.log_to_db! :zone_load, self, "Downloading zone data at #{versioned_data_path}"

      zone_request = S3.get_object(Deepworld::Settings.fog.zone_bucket, versioned_data_path)
      zone_request_io = StringIO.new(zone_request.body)

      Game.log_to_db! :zone_load, self, "Unzipping zone data"

      zone_data = Zlib::GzipReader.new(zone_request_io).read

      Game.log_to_db! :zone_load, self, "Processing zone data"

      load_binary zone_data

      Game.log_to_db! :zone_load, self, "Finished processing zone data"
    end

    def load_binary(binary)
      raise "Zone binary can't be nil (try running bootstrap)" unless binary

      # Read us some zone daterz!
      begin
        data = MessagePack.unpack(binary.force_encoding('ASCII-8BIT'))
      rescue Exception => e
        msg = "Unable to unpack #{data_path}, Zone file must be corrupt!"
        Game.info error: msg, exception: e.to_s

        raise msg
      end

      @size = Vector2.new(data[0], data[1])
      @chunk_size = Vector2.new(data[2], data[3])
      @meta_blocks = MetaBlock.unpack(self, data[5])
      index_all_meta_blocks

      @chunk_width = (@size.x / @chunk_size.x).ceil
      @chunk_height = (@size.y / @chunk_size.y).ceil
      @chunk_count = @chunk_height * @chunk_width

      # Extra data
      extra_data = (data[6] || {}).with_indifferent_access
      @liquid_reserves = extra_data[:liquid_reserves] || {100 => 0, 101 => 0, 102 => 0, 103 => 0, 104 => 0, 105 => 0}
      @chunks_explored = extra_data[:chunks_explored] || [false] * @chunk_count
      @chunks_explored_count = @chunks_explored.count{ |ch| ch }

      @kernel = ZoneKernel::Zone.new(self, @size.x, @size.y, @chunk_size.x, @chunk_size.y, data[4], Game.kernel_config)

      @liquid = ZoneKernel::Liquid.new(@kernel) if (Game.liquid_enabled and @liquid_enabled)
      @steam = ZoneKernel::Steam.new(@kernel) if Game.steam_enabled
      @light  = ZoneKernel::Light.new(@kernel)
      @growth = Dynamics::Growth.new(self)

      # Get surface levels
      @surface = (0..@size.x-1).map do |x|
        (0..@size.y-1).find { |y| peek(x, y, BASE)[0] > 0 }
      end
      @surface_max = @surface.max || 0

      # Dev info
      if ENV['INFO']
        meta_blocks_description.split("\n").each{ |b| p b }
      end

      @geck_meta_block = @meta_blocks.values.find{ |b| b.item.code == Game.item_code('mechanical/geck-tub') }
      @composter_meta_block = @meta_blocks.values.find{ |b| b.item.code == Game.item_code('mechanical/composter-chamber') }

      unless force_load
        errs = validate_field_blocks
        if errs.present?
          raise "[ERROR]: Meta block validation failed - #{errs}"
        end
      end

      true
    end

    def validate_field_blocks
      field_items = Game.item_search(/mechanical\/dish/).values.reject{ |i| i.name =~ /competition|broken/ }
      field_item_errs = []

      field_items.each do |item|
        find_items(item.code).each do |block|
          unless get_meta_block(block[0], block[1])
            field_item_errs << [block[0], block[1], item.id]
          end
        end
      end

      field_item_errs
    end

    # Persist the zone to s3, do this async!
    def persist!(serializer = nil)
      file_version_updated = false

      # This shouldn't happen but let's double bulletproof it
      @file_write_lock.synchronize do

        # Dump this check after testing
        file_version_updated = update_file_version

        if Deepworld::Env.local?
          unless ENV['SKIP_PERSIST']# || Deepworld::Env.test?
            filename = File.join(Deepworld::Env.root, 'tmp', self.data_path.split('/').last)

            write_binary(filename + ".tmp", serializer)
            FileUtils.mv filename + ".tmp", filename

            Game.info message: "Zone '#{self.name}' saved to #{self.data_path}.", zone: id.to_s
          end

          @last_saved_at = Time.now
        else
          bucket = Deepworld::Settings.fog.zone_bucket

          # Pack zone data
          serializer ||= self
          packed_data = nil
          Game.add_benchmark :zone_persist_pack do
            packed_data = MessagePack.pack(serializer.serialize)
          end

          # Compress zone data
          io = StringIO.new('w')
          Game.add_benchmark :zone_persist_gzip do
            gz = Zlib::GzipWriter.new(io, 5)
            gz.write packed_data
            gz.close
          end

          begin
            # Upload to S3
            Game.add_benchmark :zone_persist_put do
              S3.put_object bucket, "#{versioned_data_path}", io.string, {'x-amz-acl' => 'private'}
            end

            @last_saved_at = Time.now
            Game.info message: "Zone '#{self.name}' saved to #{versioned_data_path}.", zone: id.to_s
          rescue Exception => e
            retry_count ||= 0
            retry_count += 1

            Game.info message: "Zone save error (attempt ##{retry_count}) '#{self.name}' file #{versioned_data_path}, server #{self.server_id}: #{e.message}", zone: self.id.to_s, server: self.server_id, backtrace: $!.backtrace

            if retry_count <= 5 # Up to 5 times
              sleep (0.1 * retry_count)
              retry
            else
              Alert.create :zone_save_failure, :critical, "Zone failed to save after 5 attempts. Zone: '#{self.name}', Server: #{self.server_id}: #{e.message}"
            end
          end
        end
      end

      # Persist characters
      @ecosystem.persist!

      updates = {
        name_downcase: self.name.downcase,
        chunks_explored_count: @chunks_explored_count,
        explored_percent: calc_explored_percent,
        development: calc_development_level,
        machines_discovered: @machines_discovered,
        content: significant_item_counts,
        acidity: @acidity,
        command_history: @command_history,
        last_missive_check_at: @last_missive_check_at
      }

      if file_version_updated
        updates.merge!({
          file_version: @file_version,
          file_versioned_at: @file_versioned_at,
          data_path: @data_path
        })
      end

      self.update(updates)
    end

    def update_file_version
      if @file_version == 0 || (Time.now.utc.beginning_of_day > @file_versioned_at.beginning_of_day)
        @file_versioned_at = Time.now.utc
        @file_version = (@file_version % Deepworld::Settings.versioning.history) + 1

        # Capture for debugging - no longer needed
        # self.push(:file_version_hist, [@file_versioned_at, @file_version])
        return true
      end

      return false
    end

    def versioned_data_path
      self.data_path.split('.').insert(-2, @file_version).join('.')
    end

    def write_binary(file_location, serializer = nil)
      serializer ||= self

      File.open(file_location, 'wb') do |f|
        f.write MessagePack.pack(serializer.serialize)
      end
    end

    def serialize
      [
        @size.x,
        @size.y,
        @chunk_size.x,
        @chunk_size.y,
        @kernel.chunks(false),
        MetaBlock.pack(@meta_blocks),
        {
          chunks_explored: @chunks_explored
        }
      ]
    end

  end
end