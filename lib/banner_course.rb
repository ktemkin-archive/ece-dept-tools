
require 'date'
require 'time'
require 'nokogiri'

#
# Represents a course, as read from Banner.
#
class BannerCourse

  #
  # Specifies the CSS selector used to identify course tables.
  #
  COURSE_ENTRY_SELECTOR = '.pagebodydiv > table.datadisplaytable[summary="This layout table is used to present the sections found"] > tr'

  #
  # Specifies the CSS used to extract the course's header from 
  # the given course.
  #
  COURSE_HEADER_SELECTOR = 'th.ddtitle a'


  #
  # A regular expression which parses a Banner course header.
  # This is composed of four parts:
  # - A course "section name", e.g. Digital Logic Design (LEC)
  # - A course CRN.
  # - A course "number", e.g. EECE 251.
  # - A section name, e.g. A 0.
  #
  #
  COURSE_HEADER_FORMAT = /^\W(?<name>[^-]+) - (?<crn>\d+) - (?<number>[^-]+) - (?<section>[^-]+)\W$/


  #
  # A regular expression which parses a Banner course body.
  #
  COURSE_BODY_FORMAT = /(?<description>.+)\nAssociated Term: (?<term>[^\n]+).*\nRegistration Dates: (?<registration_window>[^\n]+).*(?<credit_count>\d\.\d+) Credits.*Class\n(?<time_range>[^\n]+)\n(?<days>[^\n]+)\n(?<room>[^\n]+)\n(?<date_range>[^\n]+)\n(?<type>[^\n]+)\n(?<instructor>[^\n]+)/m

  #
  # Creates an array of BannerCourses by parsing a Banner detailed course view.
  #
  # This is an ugly function-- but Banner is an ugly, ugly product. Since they provide
  # _no_ clean way to machine parse their course output, we resort to this.
  #
  def self.collection_from_html(html)

    #Parse the HTML into an XML tree.
    document = Nokogiri::HTML(html)

    #And convert each of the Data Display tables into an course node.
    nodes = []

    #Parse each of the entries in the course table.
    document.css(COURSE_ENTRY_SELECTOR).each_slice(2) do |header, body| 

      #If we have an unmatched element, skip it.
      next if header.nil? or body.nil?

      #Otherwise, use the pair of rows to get the course's information.
      nodes << self.from_data_display_table(header, body) 

    end

    #Return the newly-created collection of nodes.
    nodes

  end

  #
  # Creates a new BannerCourse from a Banner data display table.
  #
  def self.from_data_display_table(header, body)

    #Create the initial course info object from the table provided.
    info = extract_info_from_header(header)

    #Merge in any information from the body.
    info.update(extract_info_from_body(body))

    info[:date_range] = extract_dates(info[:date_range])
    info[:start_time], info[:duration] = extract_time_and_duration(info[:time_range])

    #For now, return the info directly.
    info

  end

  #
  # Converts a banner date into a defined start and end date.
  # Returns [start_date, end_date].
  # 
  def self.extract_dates(date_range)

    #Break the date range into its pieces, and then parse them.
    start_date, _,  end_date = date_range.partition(' - ')
    return Date.parse(start_date), Date.parse(end_date)

  end

  #
  # Converts a banner start and end time to a "raw" start time 
  # (which is represented as seconds past minute on a given day)
  # and a duration in seconds.
  #
  def self.extract_time_and_duration(time_range)

    #Break the time range down into its pieces.
    start_time, _, end_time = time_range.partition(' - ')
    
    #Find the starting time, with respect to the current day.
    relative_start_time = Time.parse(start_time) - Time.parse("12:00 AM")

    #Find the duration of the event, in minutes.
    duration = Time.parse(end_time) - Time.parse(start_time)

    #Return the duration (in seconds) and the relative start time.
    return relative_start_time, duration

  end


  #
  # Extract information about the course from the course's
  # header row in the course summary table.
  #
  def self.extract_info_from_header(row)
    match_data_to_hash(COURSE_HEADER_FORMAT.match(row.text))
  end


  #
  # Extract information about the course from the main body
  # of the course information in the course summary table.
  #
  def self.extract_info_from_body(row)
    puts row.text
    match_data_to_hash(COURSE_BODY_FORMAT.match(row.text))
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
