$:.push(File.join(File.dirname(__FILE__),'..','..','lib'))
require 'simple_db_persistence_support'
require 'date'
require 'aws-sdk'

describe "Amazon AWS SimpleDB PersistenceSupport loading behavior" do

  before(:each) do
    class MockDomainClass
      include Frayer::AWS::SimpleDB::PersistenceSupport

      attribute :name
      attribute :date_created, Time
      attribute :date_updated, Time
      attribute :str_value_1
      attribute :int_value_1, Integer, { padding: 16 }
      attribute :int_value_2, Integer, { padding: 8 }
      attribute :int_value_3, Integer
      attribute :time_value_1, Time
      has_strings  :str_value_2, :str_value_3
      has_ints     :int_value_4, :int_value_5
      has_dates    :time_value_2, :time_value_3, :time_value_nil
      has_booleans :bool_1, :bool_2
    end

    class MockSimpleDBAttributeCollection
      def initialize(attributes)
        @attributes = attributes
      end

      def [](name)
        @attributes.find { |attribute| attribute.name == name }
      end

      def collect(&block)
        @attributes.collect(&block)
      end

      def each(&block)
        @attributes.each(&block)
      end
    end

    @object = MockDomainClass.new
    @mock_created_time_as_string = '2012-11-05T16:07:29+00:00'
    @mock_created_time = DateTime.iso8601(@mock_created_time_as_string).to_time
    @mock_updated_time_as_string = '2012-11-06T13:01:02+00:00'
    @mock_updated_time = DateTime.iso8601(@mock_updated_time_as_string).to_time
    @mock_time_value_1_as_string = '2012-11-13T05:31:56+00:00'
    @mock_time_value_1 = DateTime.iso8601(@mock_time_value_1_as_string).to_time
    @mock_time_value_2_as_string = '2012-11-14T06:31:56+00:00'
    @mock_time_value_2 = DateTime.iso8601(@mock_time_value_2_as_string).to_time
    @mock_time_value_3_as_string = '2012-11-15T07:31:56+00:00'
    @mock_time_value_3 = DateTime.iso8601(@mock_time_value_3_as_string).to_time

    attributes = [
      stub(name: 'date_created', values: [ '2012-11-05T16:07:29+00:00' ]),
      stub(name: 'date_updated', values: [ '2012-11-06T13:01:02+00:00' ]),
      stub(name: 'str_value_1', values: [ 'String value 1 from item' ]),
      stub(name: 'str_value_2', values: [ 'String value 2 from item' ]),
      stub(name: 'str_value_3', values: [ 'String value 3 from item' ]),
      stub(name: 'int_value_1', values: [ '0000000000002012' ]),
      stub(name: 'int_value_4', values: [ '00000000000000000000' ]),
      stub(name: 'int_value_5', values: [ '18446744073709551616' ]),
      stub(name: 'undeclared_value', values: [ "This shouldn't be assigned when loaded."]),
      stub(name: 'time_value_1', values: [ '2012-11-13T05:31:56+00:00' ]),
      stub(name: 'time_value_2', values: [ '2012-11-14T06:31:56+00:00' ]),
      stub(name: 'time_value_3', values: [ '2012-11-15T07:31:56+00:00' ]),
      stub(name: 'time_value_nil', values: []),
      stub(name: 'bool_1', values: [ 'true' ]),
      stub(name: 'bool_2', values: [ 'false' ])
    ]

    item_data_attributes = {}
    attributes.each do |attribute|
      item_data_attributes[attribute.name] = attribute.values
    end

    @mock_item = mock('mock_item')
    @mock_item.stub(:name) { 'mock item name' }
    @mock_item.stub(:attributes) { MockSimpleDBAttributeCollection.new(attributes) }

    @mock_item_data = mock(AWS::SimpleDB::ItemData)
    @mock_item_data.stub(:name) { 'mock ItemData name' }
    @mock_item_data.stub(:attributes) { item_data_attributes }
  end

  describe "AWS::SimpleDB::Item loading behavior" do

    it "populates the name attribute from the item" do
      @object.load_from_item(@mock_item)
      @object.name.should eq('mock item name')
    end

    it "populates the date_created attribute frome the item" do
      @object.load_from_item(@mock_item)
      @object.date_created.should eq(@mock_created_time)
    end

    it "populates the date_updated attribute from the item" do
      @object.load_from_item(@mock_item)
      @object.date_updated.should eq(@mock_updated_time)
    end

    it "populates String attributes from the item" do
      @object.load_from_item(@mock_item)
      @object.str_value_1.should eq('String value 1 from item')
      @object.str_value_2.should eq('String value 2 from item')
      @object.str_value_3.should eq('String value 3 from item')
    end

    it "populates String attributes as Integer types when that metadata is present in the loading class" do
      @object.load_from_item(@mock_item)
      @object.int_value_1.should eq(2012)
    end

    it "doesn't populate fields from the item which are not declared in the class as attributes" do
      @object.load_from_item(@mock_item)
      @object.instance_variable_get(:@undeclared_value).should_not be
    end

    it "populates String attributes as Time types when that metadata is present in the loading class" do
      @object.load_from_item(@mock_item)
      @object.time_value_1.should eq(@mock_time_value_1)
      @object.time_value_2.should eq(@mock_time_value_2)
      @object.time_value_3.should eq(@mock_time_value_3)
      @object.time_value_nil.should be(nil)
    end

    it "assigns date_created and date_updated to nil when not present in the item" do
      attributes = [
        stub(name: 'date_created', values: []),
        stub(name: 'date_updated', values: [])
      ]
      @mock_item = mock('mock_item')
      @mock_item.stub(:name) { 'mock item name' }
      @mock_item.stub(:attributes) { MockSimpleDBAttributeCollection.new(attributes) }

      @object.load_from_item(@mock_item)

      @object.date_created.should be(nil)
      @object.date_updated.should be(nil)
    end

    it "uses default offset and padding metadata for Integers to convert the persisted String type to a Ruby Integer" do
      @object.load_from_item(@mock_item)
      @object.int_value_4.should eq(-9223372036854775808)
      @object.int_value_5.should eq(9223372036854775808)
    end

    it "populates String attributes as Boolean types when that metadata is present in the loading class" do
      @object.load_from_item(@mock_item)
      @object.bool_1.should eq(true)
      @object.bool_2.should eq(false)
    end

  end

  describe "AWS::SimpleDB::ItemData loading behavior" do

    it "does everything AWS::SimpleDB::Item does" do
      @object.load_from_item(@mock_item_data)

      @object.name.should eq('mock ItemData name')
      @object.date_created.should eq(@mock_created_time)
      @object.date_updated.should eq(@mock_updated_time)
      @object.str_value_1.should eq('String value 1 from item')
      @object.str_value_2.should eq('String value 2 from item')
      @object.str_value_3.should eq('String value 3 from item')
      @object.int_value_1.should eq(2012)
      @object.time_value_1.should eq(@mock_time_value_1)
      @object.time_value_2.should eq(@mock_time_value_2)
      @object.time_value_3.should eq(@mock_time_value_3)
      @object.time_value_nil.should be(nil)
      @object.int_value_4.should eq(-9223372036854775808)
      @object.int_value_5.should eq(9223372036854775808)
      @object.bool_1.should eq(true)
      @object.bool_2.should eq(false)
    end

  end
end
