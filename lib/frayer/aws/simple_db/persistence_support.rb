require 'date'
require 'uuid'

module Frayer
  module AWS
    module SimpleDB
      module PersistenceSupport
        module ClassMethods
          @@attribute_properties = {}
          def attribute_properties
            @@attribute_properties
          end

          def attribute(name, *args)
            attr_accessor name
            attr_symbol = "@#{name}".to_sym

            @@attribute_properties[attr_symbol] = args.length > 0 ? {type: args[0]} : {type: String}

            if args.length > 1
              @@attribute_properties[attr_symbol][:lexical_rules] = args[1]
            end
          end
        end

        def self.included(base)
          base.extend(ClassMethods)
        end

        def save_to_simpledb(domain)
          @name = UUID.generate if @name.nil? || @name.empty?
          assign_date_created
          assign_date_updated

          attributes = {}
          eligible_variables_to_persist.each do |variable|
            with_lexical_value(variable) do |lexical_value|
              attributes[variable.to_s[1..-1].to_sym] = lexical_value
            end
          end
          domain.items.create(@name, attributes)
        end

        def load_from_item(item)
          @name = item.name
          load_date_created(item)
          load_date_updated(item)

          eligible_attributes_to_load = item.attributes.collect(&:name) - ['name', 'date_created', 'date_updated']
          eligible_attributes_to_load.each do |attribute_name|
            instance_attr_symbol = "@#{attribute_name}".to_sym
            instance_attr_properties = self.class.attribute_properties[instance_attr_symbol]
            unless instance_attr_properties.nil?
              type = instance_attr_properties[:type]
              with_parsed_value(type, item.attributes[attribute_name].values.first) do |parsed_value|
                instance_variable_set(instance_attr_symbol, parsed_value)
              end
            end
          end
        end


        def assign_date_created
          unless instance_variable_defined?(:@date_created) && !@date_created.nil?
            @date_created = Time.now
          end
        end

        def assign_date_updated
          @date_updated = Time.now
        end

        def load_date_created(item)
          date_created_attribute = item.attributes['date_created']
          load_date_attribute(:@date_created, date_created_attribute)
        end

        def load_date_updated(item)
          date_updated_attribute = item.attributes['date_updated']
          load_date_attribute(:@date_updated, date_updated_attribute)
        end

        def load_date_attribute(instance_variable, date_attribute)
          if date_attribute
            instance_variable_set(instance_variable, DateTime.iso8601(date_attribute.values.first).to_time)
          end
        end

        def eligible_variables_to_persist
          instance_variables - [ :@name ]
        end

        def with_lexical_value(variable)
          value = self.instance_variable_get(variable)
          if value.is_a? String
            yield value
          elsif value.is_a? Integer
            yield lexical_int(variable, value)
          elsif value.is_a? Time
            yield DateUtil.convert_to_iso8601(value)
          end
        end

        def with_parsed_value(type, unparsed_value)
          if type == String
            yield unparsed_value
          elsif type == Integer
            yield unparsed_value.to_i
          elsif type == Time
            yield DateTime.iso8601(unparsed_value).to_time
          end
        end

        def lexical_int(variable, int_value)
          padding = 10
          lexical_rules = self.class.attribute_properties[variable][:lexical_rules]
          if lexical_rules
            padding = lexical_rules[:padding]
          end
          int_value.to_s.rjust(padding, '0')
        end
      end
    end
  end
end
