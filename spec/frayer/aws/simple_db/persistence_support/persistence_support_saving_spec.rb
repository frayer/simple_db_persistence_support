require 'simple_db_persistence_support'

describe "Amazon AWS SimpleDB PersistenceSupport saving behavior" do
  before(:each) do
    class MockClass
      include Frayer::AWS::SimpleDB::PersistenceSupport

      attribute :name
      attribute :created, Time
      attribute :updated, Time
      attribute :str_value_1
      attribute :int_value_1, Integer, { padding: 16 }
      attribute :int_value_2, Integer, { padding: 8 }
      attribute :int_value_3, Integer
      has_strings  :str_value_2, :str_value_3
      has_ints     :int_value_4, :int_value_5
      has_dates    :date_1, :date_2
      has_booleans :bool_1, :bool_2
    end

    @mock_dao = MockClass.new
    @uuid_regexp = /^([0-9a-fA-F]){8}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){4}-([0-9a-fA-F]){12}$/
    @uuid_matcher = match(@uuid_regexp)
    @iso8601_expression = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00.*$/
    @formatted_date_matcher = match(@iso8601_expression)
  end

  it "populates the 'name' of the Item with a GUID if not already assigned" do
    @mock_dao.name = nil
    @mock_dao.str_value_1 = 'string value'

    domain = mock()
    items = mock()

    domain.stub(:items).and_return(items)
    items.stub(:create)

    @mock_dao.save_to_simpledb(domain)

    @mock_dao.name.should match(@uuid_regexp)
  end

  it "creates a new Item if the 'name' is not already assigned" do
    @mock_dao.name = nil
    @mock_dao.str_value_1 = 'string value'

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, {str_value_1: 'string value', created: be, updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "sets created and updated in ISO-8601 format if it is not currently assigned" do
    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create).with(@uuid_matcher, {created: @formatted_date_matcher, updated: @formatted_date_matcher})

    @mock_dao.save_to_simpledb(domain)
  end

  it "sets created and updated in ISO-8601 format if it is assigned to nil" do
    @mock_dao.created = nil
    @mock_dao.updated = nil
    
    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create).with(@uuid_matcher, {created: @formatted_date_matcher, updated: @formatted_date_matcher})

    @mock_dao.save_to_simpledb(domain)
  end

  it "does not change the value of created if it was already assigned" do
    time = Time.new - 1000 * 60 * 60
    expected_iso_8601_date = time.utc.strftime('%FT%T%:z')
    @mock_dao.created = time

    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create).with(@uuid_matcher, {created: expected_iso_8601_date, updated: @formatted_date_matcher})

    @mock_dao.save_to_simpledb(domain)
  end

  it "changes the value of updated if it was already assigned" do
    time = Time.new - 1000 * 60 * 60
    expected_iso_8601_date = time.utc.strftime('%FT%T%:z')
    @mock_dao.created = time
    @mock_dao.updated = time

    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create) do |name, attributes|
      attributes[:updated].should_not be(expected_iso_8601_date)
      attributes[:updated].should match(@iso8601_expression)
    end

    @mock_dao.save_to_simpledb(domain)
  end

  it "updates the Item using its existing 'name' if already assigned" do
    @mock_dao.name = '12345'
    @mock_dao.str_value_1 = 'string value'

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with('12345', {str_value_1: 'string value', created: be, updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "zero-pad's Integer types to their configured length when saving" do
    @mock_dao.int_value_1 = 329000
    @mock_dao.int_value_2 = 1309000

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, {int_value_1: '0000000000329000', int_value_2: '01309000', created: be, updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "defaults the zero-padding of an Integer to 10 if not defined in the lexical_rules" do
    @mock_dao.int_value_1 = 329000
    @mock_dao.int_value_2 = 1309000
    @mock_dao.int_value_3 = 12345678

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, {int_value_1: '0000000000329000', int_value_2: '01309000', int_value_3: '0012345678', created: be, updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "adds the default offset and padding to Integer values defined with has_ints when saving" do
    @mock_dao.int_value_4 = -9223372036854775808
    @mock_dao.int_value_5 = 9223372036854775808

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, {int_value_4: '00000000000000000000', int_value_5: '18446744073709551616', created: be, updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "allows String attributes defined with 'has_strings' to be persisted" do
    @mock_dao.str_value_2 = 'string value 2'
    @mock_dao.str_value_3 = 'string value 3'

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, {str_value_2: 'string value 2', str_value_3: 'string value 3', created: be, updated: be })

    @mock_dao.save_to_simpledb(domain)
  end

  it "allows Time attributes defined with 'has_dates' to be persisted" do
    time_1 = Time.new - 1000 * 60 * 60
    time_2 = Time.new - 2000 * 60 * 60
    expected_iso_8601_date_1 = time_1.utc.strftime('%FT%T%:z')
    expected_iso_8601_date_2 = time_2.utc.strftime('%FT%T%:z')
    @mock_dao.date_1 = time_1
    @mock_dao.date_2 = time_2

    domain = mock()
    items = mock()

    domain.should_receive(:items).and_return(items)
    items.should_receive(:create).with(@uuid_matcher, {date_1: expected_iso_8601_date_1, date_2: expected_iso_8601_date_2, created: be, updated: be})

    @mock_dao.save_to_simpledb(domain)
  end

  it "allows Boolean attributes defined with 'has_booleans' to be persisted" do
    @mock_dao.bool_1 = true
    @mock_dao.bool_2 = false

    domain = mock()
    items = mock()

    domain.should_receive(:items) { items }
    items.should_receive(:create).with(@uuid_matcher, { bool_1: 'true', bool_2: 'false' , created: be, updated: be })

    @mock_dao.save_to_simpledb(domain)
  end
end
