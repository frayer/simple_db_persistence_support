require 'date'
require 'uuid'

module Frayer
  module AWS
    module SimpleDB
      module PersistenceSupport
        class Boolean; end

        module ClassMethods
          @@default_offset = 9223372036854775808
          @@default_padding = 20
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

          def has_strings(*args)
            args.each do |arg|
              attribute(arg, String)
            end
          end

          def has_ints(*args)
            args.each do |arg|
              attribute(arg, Integer, { offset: @@default_offset, padding: @@default_padding })
            end
          end

          def has_floats(*args)
            args.each do |arg|
              attribute(arg, Float)
            end
          end

          def has_dates(*args)
            args.each do |arg|
              attribute(arg, Time)
            end
          end

          def has_booleans(*args)
            args.each do |arg|
              attribute(arg, Boolean)
            end
          end

          def lexical_int(variable, int_value)
            offset = 0
            padding = 10
            lexical_rules = @@attribute_properties[variable][:lexical_rules]
            if lexical_rules
              offset = lexical_rules[:offset] if lexical_rules[:offset]
              padding = lexical_rules[:padding] if lexical_rules[:padding]
            end
            lexical_int = int_value + offset
            lexical_int.to_s.rjust(padding, '0')
          end

          def lexical_date(date)
            DateUtil.convert_to_iso8601(date)
          end

          def all(domain)
            self.select(domain, :all)
          end

          def select(domain, *attributes)
            properties = []
            domain.items.select(*attributes) do |item|
              properties << property_from_item(item)
            end
            properties
          end

          def where(domain, conditions, *substitutions)
            properties = []
            domain.items.where(conditions, *substitutions).select(:all) do |item|
              properties << property_from_item(item)
            end
            properties
          end

          def property_from_item(item)
            property = nil
            self.class_exec do
              property = new
              property.load_from_item(item)
            end
            property
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

          eligible_attributes_to_load = retrieve_attribute_names(item)
          eligible_attributes_to_load.each do |attribute_name|
            instance_attr_symbol = "@#{attribute_name}".to_sym
            instance_attr_properties = self.class.attribute_properties[instance_attr_symbol]
            unless instance_attr_properties.nil?
              type = instance_attr_properties[:type]
              unparsed_value = retrieve_attribute_value(item, attribute_name)
              with_parsed_value(type, instance_attr_properties, unparsed_value) do |parsed_value|
                instance_variable_set(instance_attr_symbol, parsed_value)
              end
            end
          end
        end

        def to_h
          Hash[instance_variables.map { |var| [var[1..-1].to_sym, instance_variable_get(var) ] }]
        end

        def retrieve_attribute_names(item)
          excluded_attribute_names = ['name', 'created', 'updated']
          if item.attributes.instance_of?(Hash)
            item.attributes.keys - excluded_attribute_names
          else
            item.attributes.collect(&:name) - excluded_attribute_names
          end
        end

        def retrieve_attribute_value(item, attribute_name)
          attribute_values = item.attributes[attribute_name]
          if attribute_values.instance_of?(Array)
            attribute_values.first
          elsif attribute_values.respond_to?(:values)
            attribute_values.values.first
          end
        end

        def assign_date_created
          unless instance_variable_defined?(:@created) && !@created.nil?
            @created = Time.now
          end
        end

        def assign_date_updated
          @updated = Time.now
        end

        def load_date_created(item)
          date_created_value = retrieve_attribute_value(item, 'created')
          load_date_attribute(:@created, date_created_value)
        end

        def load_date_updated(item)
          date_updated_value = retrieve_attribute_value(item, 'updated')
          load_date_attribute(:@updated, date_updated_value)
        end

        def load_date_attribute(instance_variable, date_value)
          if date_value
            instance_variable_set(instance_variable, DateTime.iso8601(date_value).to_time)
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
            yield self.class.lexical_int(variable, value)
          elsif value.is_a? Float
            yield value.to_s
          elsif value.is_a? Time
            yield self.class.lexical_date(value)
          elsif value == true || value == false
            yield value.to_s
          end
        end

        def with_parsed_value(type, instance_attr_properties, unparsed_value)
          if unparsed_value.nil?
            yield nil
          elsif type == String
            yield unparsed_value
          elsif type == Integer
            yield parsed_int(instance_attr_properties, unparsed_value)
          elsif type == Float
            yield unparsed_value.to_f
          elsif type == Time
            yield DateTime.iso8601(unparsed_value).to_time
          elsif type == Boolean
            if unparsed_value == 'true'
              yield true
            else
              yield false
            end
          end
        end

        def parsed_int(instance_attr_properties, unparsed_value)
          int_value = unparsed_value.to_i
          if (instance_attr_properties[:lexical_rules] && instance_attr_properties[:lexical_rules][:offset])
            int_value -= instance_attr_properties[:lexical_rules][:offset]
          end
          return int_value
        end
      end
    end
  end
end
