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

require 'date'
require 'time'
require 'nokogiri'

#
# Represents a course, as read from Banner.
#
class BannerCourse

  #
  # Store the list of day codes that banner uses to represent class occurrences.
  # In order, starting from Sunday.
  #
  DAY_CODES = ['U', 'M', 'T', 'W', 'R', 'F', 'S']

  #
  # Specifies the CSS selector used to identify course tables.
  #
  COURSE_ENTRY_SELECTOR = '.pagebodydiv > table.datadisplaytable[summary="This layout table is used to present the sections found"] > tr'

  #
  # A regular expression which parses a Banner course header.
  # This is composed of four parts:
  # - A course "section name", e.g. Digital Logic Design (LEC)
  # - A course CRN.
  # - A course "number", e.g. EECE 251.
  # - A section name, e.g. A 0.
  #
  #
  COURSE_HEADER_FORMAT = /^\W*(?<name>[^-]+) - (?<crn>\d+) - (?<number>[^-]+) - (?<section>[^-]+)\W*$/

  #
  # A regular expression which parses a Banner course body.
  #
  COURSE_BODY_FORMAT = /(?<description>.+)\nAssociated Term: (?<term>[^\n]+).*\nRegistration Dates: (?<registration_window>[^\n]+).*(?<credit_count>\d\.\d+) Credits/m

  #
  # A regular expression which parses a Banner meet pattern.
  #
  COURSE_MEET_FORMAT = /Class\n(?<time_range>[^\n]+)\n(?<days>[^\n]+)\n(?<room>[^\n]+)\n(?<date_range>[^\n]+)\n(?<type>[^\n]+)\n(?<instructor>[^\n]+)/m

  
  #
  # Define the course parameters which we want to be readable.
  #
  # In typical use, these parameters are provided upon instantiation;
  # and are typically extracted from one of the regular expressions above.
  # 
  attr_reader :crn, :name, :number, :section, :description, :term
  attr_reader :credit_count, :days, :room, :type, :instructor        
  attr_reader :start_time, :end_time, :date_range, :registration_window

  # Stores the total amount of simultaneous "sessions" that are occurring
  # in this entry. In most cases, a single object will represent only a 
  # single session. This is changed when multiple near-identical sessions
  # are merged into one.
  attr_accessor :count

  #
  # Creates a new BannerClass object from a hash of properties.
  #
  def initialize(properties)

    #Convert the properties into (publically accessible) instance variables.
    properties.each do |name, value|
      instance_variable_set "@#{name}", value
    end

    #By default, count each course entry as only a single section
    #at the given time. This can be changed by 
    @count = 1

  end

  #
  # Creates an array of BannerCourses by parsing a Banner detailed course view.
  #
  # This is an ugly function-- but Banner is an ugly, ugly product. Since they provide
  # _no_ clean way to machine parse their course output, we resort to this.
  #
  def self.collection_from_html(document)

    #If we've been passed a string, convert it to a Nokogiri HTML document.
    document = Nokogiri::HTML(document) if document.is_a? String

    #And convert each of the Data Display tables into an course node.
    nodes = []

    #Parse each of the entries in the course table.
    each_data_display_table_in(document) do |header, body, meet_pattern|

      #If we have an unmatched element, skip it.
      next if header.nil? or body.nil?

      #Otherwise, use the pair of rows to get the course's information.
      begin
        nodes << self.from_data_display_table(header, body, meet_pattern) 
      rescue ArgumentError, NoMethodError
      end

    end

    #Return the newly-created collection of nodes.
    nodes

  end


  #
  # Creates a new BannerCourse from a Banner data display table.
  #
  def self.from_data_display_table(header, body, meet_pattern)
    

    #If we were given HTML strings, parse them.
    header       = Nokogiri::HTML(header) if header.is_a? String 
    body         = Nokogiri::HTML(body) if body.is_a? String 

    #Create the initial course info object from the table provided.
    info = extract_info_from_header(header)

    #Merge in any information from the body.
    info.update(extract_info_from_body(body))
    info.update(extract_info_from_meet_pattern(meet_pattern))

    #Parse the date ranges.
    info[:date_range] = extract_dates(info[:date_range])
    info[:registration_window] = extract_dates(info[:registration_window], ' to ')

    #Convert each of the numeric parameters to Ruby's internal representations.
    info[:crn] = info[:crn].to_i
    info[:credit_count] = info[:credit_count].to_f

    #Extract the starting and ending times.
    info[:start_time], info[:end_time] = extract_times(info[:time_range])

    #Convert the info into a BannerClass object.
    new(info)

  end

  #
  # Converts a CSV row to a Banner course instance.
  # Requires an object containing all known class properties;
  # which should include at least a date_range.
  #
  def self.from_csv_row(csv, info={})
   
    #TODO: abstract to class const  
    mappings = {
      'CRN' => :crn,
      'Title Short Desc' => :name,
      'Cr' => :credit_count,
      'Meet' => :days,
      'Instructor' => :instructor,
      'Location' => :room,
      'Type' => :type
    }

    #Create the info object from the CSV field 
    info = Hash[mappings.map {|k, v| [v, csv[k]] }] 

    #Populate the fields that aren't a direct mapping.
    info[:number] = "#{csv['Dept']} #{csv['#']}".strip
    info[:start_time] = parse_csv_time(csv['Begin']) if csv['Begin']
    info[:end_time] = parse_csv_time(csv['End']) if csv['End'] 

    #If no date range was provided, use the current week.
    unless info[:date_range]

      #Compute Date objects for the previous Sunday, and the next Saturday.
      today = Date.today
      sunday = today - today.wday
      saturday = sunday + 6

      #Convert the two dates to DateTimes.
      #TODO: DRY up?
      sunday = DateTime.parse(sunday.to_s)
      saturday = DateTime.parse(saturday.to_s)
      
      #... and use them to populate a date range.
      info[:date_range] = (sunday..saturday)
    end

    #Convert the info into a BannerClass object.
    new(info)

  end

  #
  # Returns an array of every _time_ at which a session 
  # occurs.
  # 
  def each_session_date

    #If we weren't provided a block, convert this into an
    #enumerator.
    return enum_for(:each_session_date) unless block_given?

    #Iterate over each day in which the given event can occur.
    #If the event occurs on any given day, yield the time at
    #which it occurs.
    date_range.each do |day|
      yield day + start_time if occurs_on?(day)
    end

  end

  #
  # Iterates over each of the session times for this 
  #
  def all_session_dates
    each_session_date.to_a
  end

  #
  # Returns true iff the given class should occur on the given day.
  #
  def occurs_on?(day)
    date_range.include?(day) and days.include?(DAY_CODES[day.wday])
  end

  
  #
  # Returns true iff the provided BannerCourse is a different instance
  # of this course. Courses are considered to be different instances of
  # the same course if they have the same number, time, and type
  #
  def similar_to?(other)
    start_time == other.start_time and 
      type     == other.type       and 
      number   == other.number     and
      end_time == other.end_time   and
      days     == other.days
  end


  #
  # Merges a collection of course instances, 
  #
  def self.merge_course_instances(instances)

    #Create a copy of the first provided instance.
    new_instance = instances.first.clone

    #Set its count to reflect the total amount of sessions...
    new_instance.instance_variable_set(:@count, instances.count)

    #If any of the instances have a different instructor, set the instructor to "multiple".
    unless instances.all? { |instance| instance.instructor ==  new_instance.instructor}
      new_instance.instance_variable_set(:@instructor, 'Multiple')
    end

    #Return the new instance.
    new_instance

  end


  #
  # Merges any "similar" sessions into a single session element.
  # Uses the definition of similiarity defined by "similar_to?" above.
  #
  def self.merge_similar_sessions(collection)

    #Create an empty collection for the result.
    new_collection = []

    #Group similar sessions by "similarity hash".
    groups = collection.group_by { |course| similarity_hash(course) }

    #Merge all of the similar sessions into single elements, and add them to the collection.
    #Sessions which have no similar sections will be added to the collection unmodified.
    groups.each { |hash, group| new_collection << merge_course_instances(group) }

    #Return the modified collection.
    new_collection

  end

  def inspect
    "<BannerCourse: #@number at #@time_range, #@days>"
  end



  private

  #
  # Iterates over each Data Display Table found in the given document.
  # Data display tables are the fundamental "unit" of Banner course displays.
  #
  def self.each_data_display_table_in(document)

    #Start off by assuming we don't have a header.
    header = nil

    #Iterate overy each course "entry".
    #Banner's format isn't exactly condusive to parsing:
    #headers and bodies are encoded identically. We pull
    #them apart according to which regex they match.
    document.css(COURSE_ENTRY_SELECTOR).each do |entry|

      #If the given item is a course header,
      #store it, and continue to the next entry.
      if COURSE_HEADER_FORMAT =~ entry
        header = entry
        next
      end

      #If we don't have a valid header, continue.
      next unless header

      #Yields the relevant information for each meet pattern in a given
      #data display table.
      each_meet_pattern_in(entry) { |meet| yield header, entry, meet }

    end
  end

  #
  # Iterates over each meet pattern present in a banner course body.
  #
  def self.each_meet_pattern_in(display_table_body)
    #This is ugly, but it's apparently the best way to get "all matching strings" in ruby.
    display_table_body.text.scan(COURSE_MEET_FORMAT) { yield Regexp.last_match.to_s }
  end


  #
  # Returns a simple "hash", which can be used to identify similar strings.
  # This value will be the same for any two courses which are similar, and
  # different otherwise.
  #
  def self.similarity_hash(course)
    "#{course.start_time}-#{course.end_time}-#{course.type}-#{course.number}-#{course.days}"
  end


  #
  # Converts a banner date into a defined start and end date.
  # Returns [start_date, end_date].
  # 
  def self.extract_dates(date_range, partition = ' - ')

    #Break the date range into its pieces, and then parse them.
    start_date, _,  end_date = date_range.partition(partition)
    return (DateTime.parse(start_date)..DateTime.parse(end_date))

  end

  #
  # Converts a banner start and end time to a "raw" start time 
  # (which is represented as seconds past minute on a given day)
  # and a duration in seconds.
  #
  def self.extract_times(time_range, partition = ' - ')

    #Break the time range down into its pieces.
    start_time, _, end_time = time_range.partition(partition)

    #Get a reference to midnight.
    midnight = DateTime.parse("12:00 AM")
    
    #Find the starting time, with respect to the current day.
    relative_start_time = DateTime.parse(start_time) - midnight

    #Find the end time, with respect to the current day.
    relative_end_time = DateTime.parse(end_time) - midnight

    #Return the duration (in seconds) and the relative start time.
    return relative_start_time, relative_end_time

  end

  #
  # Converts a CSV time to a "raw" time, in the same format as
  # the two times returned by extract_times.
  #
  def self.parse_csv_time(time)

    #Ensure the time has exactly four characters,
    #adding leading zeroes are necessary.
    time = time.rjust(4, '0')

    #Convert the time to a format Ruby can understand...
    time = "#{time[0..1]}:#{time[2..3]}"

    #Return the starting time, with respect to the current day.
    DateTime.parse(time) - DateTime.parse("12:00 AM")

  end


  #
  # Extract information about the course from the course's
  # header row in the course summary table.
  #
  def self.extract_info_from_header(row)
    extract_data_using(COURSE_HEADER_FORMAT, row.text)
  end


  #
  # Extract information about the course from the main body
  # of the course information in the course summary table.
  #
  def self.extract_info_from_body(row)
    extract_data_using(COURSE_BODY_FORMAT, row.text)
  end

  def self.extract_info_from_meet_pattern(meet_pattern)
    extract_data_using(COURSE_MEET_FORMAT, meet_pattern)
  end

  #
  # Extracts information from a string using the provided
  # regular expression, which should include named matches.
  #
  def self.extract_data_using(regexp, string)
    
    #If we have a non-string, see if it can be converted to a string.
    string = string.text if string.respond_to?(:text)

    #Extact the data itself.
    match_data_to_hash(regexp.match(string))

  end


  #
  # Converts a collection of match data into a hash.
  #
  def self.match_data_to_hash(match_data)
 
    #Convert the match names to symbols...
    symbols = match_data.names.map { |name| name.to_sym }

    #Remove any leading and trailing whitespace from the match_data.
    captures = match_data.captures.map { |value| value.strip }

    #... and convert the symbols and match data to a new Hash.
    Hash[symbols.zip(captures)]
  end


end
