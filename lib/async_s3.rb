class AsyncS3
  GZIP_LEVEL = 5

  # Gets object async, optionally inflates
  def get_object(bucket, path, gz = false)
    operation = Proc.new do
      begin
        request = S3.get_object(Deepworld::Settings.fog.bucket, data_path)
        yield gz ? decompress(request.body) : request.body
      rescue Exception => e
        Game.info message: "Unable to load file bucket:#{bucket}, path:#{path}", exception: $!, backtrace: $!.backtrace
        yield nil
      end
    end

    EM.defer(operation, block)
  end

  private

  def decompress(data)
    io = StringIO.new(data)
    Zlib::GzipReader.new(zone_request_io).read
  end

  def compress(data)
    wio = StringIO.new('w')
    gz  = Zlib::GzipWriter.new(wio,GZIP_LEVEL)
    gz.write(data)
    gz.close

    wio.string
  end
end