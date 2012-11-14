$:.push(File.join(File.dirname(__FILE__),'..','..','lib'))
require 'simple_db_persistence_support'

describe "Amazon AWS SimpleDB PersistenceSupport saving behavior" do
  before(:each) do
    class MockClass
      include Frayer::AWS::SimpleDB::PersistenceSupport

      attribute :name
      attribute :date_created, Time
      attribute :date_updated, Time
      attribute :str_value
      attribute :int_value_1, Integer, { padding: 16 }
      attribute :int_value_2, Integer, { padding: 8 }
      attribute :int_value_3, Integer
    end

    @mock_dao = MockClass.new
    @uuid_regexp = /^([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}$/
    @uuid_matcher = match(@uuid_regexp)
    @iso8601_expression = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00.*$/
    @formatted_date_matcher = match(@iso8601_expression)
  end

  it "populates the 'name' of the Item with a GUID if not already assigned" do
    @mock_dao.name = nil
    @mock_dao.str_value = 'string value'

    domain = mock()
    items = mock()

    domain.stub(:items).and_return(items)
    items.stub(:create)

    @mock_dao.save_to_simpledb(domain)

    @mock_dao.name.should match(@uuid_regexp)
  end

  it "creates a new Item if the 'name' is not already assigned" do
    @mock_dao.name = nil
    @mock_dao.str_value = 'string value'

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, {str_value: 'string value', date_created: be, date_updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "sets date_created and date_updated in ISO-8601 format if it is not currently assigned" do
    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create).with(@uuid_matcher, {date_created: @formatted_date_matcher, date_updated: @formatted_date_matcher})

    @mock_dao.save_to_simpledb(domain)
  end

  it "sets date_created and date_updated in ISO-8601 format if it is assigned to nil" do
    @mock_dao.date_created = nil
    @mock_dao.date_updated = nil
    
    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create).with(@uuid_matcher, {date_created: @formatted_date_matcher, date_updated: @formatted_date_matcher})

    @mock_dao.save_to_simpledb(domain)
  end

  it "does not change the value of date_created if it was already assigned" do
    time = Time.new - 1000 * 60 * 60
    expected_iso_8601_date = time.utc.strftime('%FT%T%:z')
    @mock_dao.date_created = time

    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create).with(@uuid_matcher, {date_created: expected_iso_8601_date, date_updated: @formatted_date_matcher})

    @mock_dao.save_to_simpledb(domain)
  end

  it "changes the value of date_updated if it was already assigned" do
    time = Time.new - 1000 * 60 * 60
    expected_iso_8601_date = time.utc.strftime('%FT%T%:z')
    @mock_dao.date_created = time
    @mock_dao.date_updated = time

    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create) do |name, attributes|
      attributes[:date_updated].should_not be(expected_iso_8601_date)
      attributes[:date_updated].should match(@iso8601_expression)
    end

    @mock_dao.save_to_simpledb(domain)
  end

  it "updates the Item using its existing 'name' if already assigned" do
    @mock_dao.name = '12345'
    @mock_dao.str_value = 'string value'

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with('12345', {str_value: 'string value', date_created: be, date_updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "zero-pad's Integer types to their configured length when saving" do
    @mock_dao.int_value_1 = 329000
    @mock_dao.int_value_2 = 1309000

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, {int_value_1: '0000000000329000', int_value_2: '01309000', date_created: be, date_updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "defaults the zero-padding of an Integer to 10 if not defined in the lexical_rules" do
    @mock_dao.int_value_1 = 329000
    @mock_dao.int_value_2 = 1309000
    @mock_dao.int_value_3 = 12345678

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, {int_value_1: '0000000000329000', int_value_2: '01309000', int_value_3: '0012345678', date_created: be, date_updated: be })

    @mock_dao.save_to_simpledb(domain)
  end
end
