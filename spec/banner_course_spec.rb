require 'banner_course'

#
# Tests for the BannerCourse object.
# 
describe BannerCourse do



  #
  # Tests for the function which extracts hash data from strings.
  # 
  describe ".extract_data_using" do
  
    let(:regular_expression) { /(?<numbers>\d+)(?<letters>[ a-z]+)/ }
    subject { BannerCourse.send(:extract_data_using, regular_expression, "1234 abcd")}

    it "should convert each match name to a symbol" do
      subject.should include(:numbers)
      subject.should include(:letters)
    end

    it "should create a hash element for each piece of match data" do 
      subject[:numbers].should == "1234"
    end

    it "should strip all leading and trailing whitespace from each match element" do
      subject[:letters].should == "abcd"
    end

  end


end

