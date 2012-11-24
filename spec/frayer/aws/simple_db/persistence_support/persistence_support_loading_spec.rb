$:.push(File.join(File.dirname(__FILE__),'..','..','lib'))
require 'simple_db_persistence_support'
require 'date'

describe "Amazon AWS SimpleDB PersistenceSupport loading behavior" do

  before(:each) do
    class MockDomainClass
      include Frayer::AWS::SimpleDB::PersistenceSupport

      attribute :name
      attribute :date_created, Time
      attribute :date_updated, Time
      attribute :str_value
      attribute :int_value_1, Integer, { padding: 16 }
      attribute :int_value_2, Integer, { padding: 8 }
      attribute :int_value_3, Integer
      attribute :misc_time, Time
      has_ints  :int_value_4, :int_value_5
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
    @mock_misc_time_as_string = '2012-11-13T05:31:56+00:00'
    @mock_misc_time = DateTime.iso8601(@mock_misc_time_as_string).to_time

    attributes = [
      stub(name: 'date_created', values: [ '2012-11-05T16:07:29+00:00' ]),
      stub(name: 'date_updated', values: [ '2012-11-06T13:01:02+00:00' ]),
      stub(name: 'str_value', values: [ 'String value from item' ]),
      stub(name: 'int_value_1', values: [ '0000000000002012' ]),
      stub(name: 'int_value_4', values: [ '00000000000000000000' ]),
      stub(name: 'int_value_5', values: [ '18446744073709551616' ]),
      stub(name: 'undeclared_value', values: [ "This shouldn't be assigned when loaded."]),
      stub(name: 'misc_time', values: [ '2012-11-13T05:31:56+00:00' ])
    ]
    @mock_item = mock('mock_item')
    @mock_item.stub(:name) { 'mock item name' }
    @mock_item.stub(:attributes) { MockSimpleDBAttributeCollection.new(attributes) }
  end

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
    @object.str_value.should eq('String value from item')
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
    @object.misc_time.should eq(@mock_misc_time)
  end

  it "uses default offset and padding metadata for Integers to convert the persisted String type to a Ruby Integer" do
    @object.load_from_item(@mock_item)
    @object.int_value_4.should eq(-9223372036854775808)
    @object.int_value_5.should eq(9223372036854775808)
  end
end
