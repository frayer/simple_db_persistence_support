module Frayer
  module AWS
    module SimpleDB
      module DateUtil
        def self.convert_to_iso8601(date)
          if (date.respond_to?(:to_time))
            date.to_time.utc.strftime('%FT%T%:z')
          elsif date.respond_to?(:utc)
            date.utc.strftime('%FT%T%:z')
          end
        end
      end
    end
  end
end
