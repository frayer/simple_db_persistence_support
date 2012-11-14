module Frayer
  module AWS
    module SimpleDB
      module DateUtil
        def DateUtil.convert_to_iso8601(time)
          time.utc.strftime('%FT%T%:z')
        end
      end
    end
  end
end
