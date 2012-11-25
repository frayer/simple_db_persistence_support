require 'simple_db_persistence_support'

describe "DateUtil" do
  it "formats a time per the ISO-8601 standard with UTC as the time zone" do
    edt_time = Time.new(2012, 4, 7, 8, 30, 45).localtime('-04:00')
    Frayer::AWS::SimpleDB::DateUtil.convert_to_iso8601(edt_time).should eq('2012-04-07T12:30:45+00:00')
  end
end