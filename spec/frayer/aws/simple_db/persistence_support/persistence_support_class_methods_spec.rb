require 'simple_db_persistence_support'
require 'date'

describe "Amazon AWS SimpleDB PersistenceSupport ClassMethods behavior" do
  before(:each) do
    class MockDomainClass
      include Frayer::AWS::SimpleDB::PersistenceSupport
      has_ints  :int_value
      has_dates :date_value
    end

    @mock_domain_class = MockDomainClass
  end

  it "produces lexical integers with correct offset and padding" do
    @mock_domain_class.lexical_int(:@int_value, -9223372036854775808).should eq('00000000000000000000')
    @mock_domain_class.lexical_int(:@int_value,  9223372036854775808).should eq('18446744073709551616')
  end

  it "produces lexical dates when passed an instance of Time" do
    @mock_domain_class.lexical_date(Time.utc(2012, 11, 25, 13, 1, 11)).should eq('2012-11-25T13:01:11+00:00')
  end

  it "produces lexical dates when passed an instance of Date" do
    @mock_domain_class.lexical_date(DateTime.new(2012, 11, 25, 13, 1, 11)).should eq('2012-11-25T13:01:11+00:00')
  end

  it "returns nil when trying to lexify a non Time or Date instance" do
    @mock_domain_class.lexical_date("I'm no date").should be(nil)
  end
end
