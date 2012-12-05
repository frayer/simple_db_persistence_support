require 'simple_db_persistence_support'

describe "Amazon AWS SimpleDB PersistenceSupport hashing behavior" do
  before(:each) do
    class MockClass
      include Frayer::AWS::SimpleDB::PersistenceSupport

      has_strings  :str_value_1, :str_value_2
      has_ints     :int_value_1, :int_value_2
      has_floats   :float_value_1, :float_value_2
      has_dates    :date_1, :date_2
      has_booleans :bool_1, :bool_2
    end

    @mock_class = MockClass.new
    @mock_class.str_value_1 = "String value 1"
    @mock_class.str_value_2 = "String value 2"
    @mock_class.int_value_1 = 2000
    @mock_class.int_value_2 = 2012
    @mock_class.float_value_1 = 123.456789
    @mock_class.float_value_2 = 987654.321
    @mock_class.date_1 = Time.new(2012, 12, 5)
    @mock_class.date_2 = Time.new(2012, 1, 20)
    @mock_class.bool_1 = false
    @mock_class.bool_2 = true
  end

  it "creates a Hash based on the available instance variables" do
    hash = @mock_class.to_h
    hash[:str_value_1].should eq("String value 1")
    hash[:str_value_2].should eq("String value 2")
    hash[:int_value_1].should eq(2000)
    hash[:int_value_2].should eq(2012)
    hash[:float_value_1].should eq(123.456789)
    hash[:float_value_2].should eq(987654.321)
    hash[:date_1].should eq(Time.new(2012, 12, 5))
    hash[:date_2].should eq(Time.new(2012, 1, 20))
    hash[:bool_1].should eq(false)
    hash[:bool_2].should eq(true)
  end
end
