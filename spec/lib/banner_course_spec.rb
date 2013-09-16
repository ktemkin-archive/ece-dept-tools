# 
# The MIT License (MIT)
# 
# Copyright (c) 2013 Binghamton University
# Copyright (c) 2013 Kyle J. Temkin <ktemkin@binghamton.edu>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# 

require 'spec_helper'
require 'banner_course'
require 'nokogiri'

#
# Tests for the BannerCourse class.
# 
describe BannerCourse do

  load_asset_file __FILE__ 

  let(:sample_course) { BannerCourse.from_data_display_table(assets[:header], assets[:body]) }

  #
  # Tests for the function which extracts hash data from strings.
  # 
  describe ".extract_data_using" do
  
    #Provide a sample regular expression with named match patterns.
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

  #
  # Tests for the function which converts Banner "data display tables" into course information
  #
  describe ".from_data_display_table" do
    subject { sample_course }

    #Test to ensure that the subject function above correctly produced a BannerCourse.
    it { should be_an_instance_of BannerCourse}

    #Test all of the properties of the resultant Banner course.
    its(:crn)                 { should == 10406 }
    its(:number)              { should == "EECE 251" }
    its(:section)             { should == "A 0" }
    its(:description)         { should start_with "Fundamental and advanced" and should end_with "non-refundable therafter." }
    its(:term)                { should == "Fall 2013" }
    its(:credit_count)        { should == 4.0 }
    its(:days)                { should == "MWF" }
    its(:room)                { should == "University Union 209" }
    its(:type)                { should == "Lecture" }
    its(:instructor)          { should == "Kyle James  Temkin (P)"}
    its(:start_time)          { should == DateTime.parse('10:50 AM') - DateTime.parse('12:00 AM') }
    its(:end_time)            { should == DateTime.parse('11:50 AM') - DateTime.parse('12:00 AM') }
    its(:date_range)          { should == (DateTime.parse("2013-08-26")..DateTime.parse("2013-12-13")) }
    its(:registration_window) { should == (DateTime.parse("2013-04-05")..DateTime.parse("2013-09-16")) }

  end

  #
  # Tests for the function that parses raw Banner course-listing pages.
  #
  describe ".collection_from_html" do

    #Process a full HTML course list.
    subject { BannerCourse.collection_from_html(assets[:full]) }

    it { should be_a Array }
    it { should have(6).items }

    its "result should contain only BannerCourses" do
      subject.each { |element| expect(element).to be_a BannerCourse }
    end

    it "should correctly extract courses from the provided document" do
      expect(subject[2].term).to eq("Fall 2013")
    end

  end

  #
  # Test the algorithm that determines whether the class occurs on a given day.
  #
  describe "#occurs_on?" do

    context "when the date occurs on a class day" do
      subject { Date.parse('2013-09-16')}

      it "returns true" do
        expect(sample_course.occurs_on?(subject)).to be_true
      end

    end

    context "when the date is not a day in which the class occurs" do
      subject { Date.parse('2013-09-15')}

      it "returns false" do
        expect(sample_course.occurs_on?(subject)).to be_false
      end
    end

  end

  #
  # Test the function that enumerates a list of session times.
  #
  describe "#all_session_dates" do

    subject { sample_course.all_session_dates }

    #It should start on the relevant dates.
    it { should start_with DateTime.parse('2013-08-26') }
    it { should end_with   DateTime.parse('2013-12-13') }

    #It should have enough elements for 16 weeks, at thrice a week.
    it { should have(16 * 3).items }

  end


end

