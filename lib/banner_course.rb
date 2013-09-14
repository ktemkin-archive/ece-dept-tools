
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
  COURSE_HEADER_FORMAT = /^(?<name>[^-]+) - (?<crn>\d+) - (?<number>[^-]+) - (?<section>[^-]+)$/


  #
  # A regular expression which parses a Banner course body.
  # TODO: Update me to include the course description / credits / etc?
  #
  COURSE_BODY_FORMAT = /(?<description>[^\n]+).*Class\n(?<time>[^\n]+)\n(?<days>[^\n]+)\n(?<room>[^\n]+)\n(?<dates>[^\n]+)\n(?<type>[^\n]+)\n(?<instructor>[^\n]+)/m

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

  end

  #
  # Creates a new BannerCourse from a Banner data display table.
  #
  def self.from_data_display_table(header, body)

    #Create the initial course info object from the table provided.
    info = extract_info_from_header(header)

    #Merge in any information from the body.
    info.update(extract_info_from_body(body))

    p info
    
    #For now, return the info directly.
    info

  end


  #
  # 
  #
  def self.extract_info_from_header(row)

    #Extract the course's header text from the course info.
    header_element = row.css(COURSE_HEADER_SELECTOR).first
    header_text = header_element.text

    #And return the core course information. 
    match_data_to_hash(COURSE_HEADER_FORMAT.match(header_text))

  end


  def self.extract_info_from_body(row)
    match_data_to_hash(COURSE_BODY_FORMAT.match(row.text))
  end


  def self.match_data_to_hash(match_data)
 
    #Convert the match names to symbols...
    symbols = match_data.names.map { |name| name.to_sym }

    #... and convert the symbols and match data to a new Hash.
    Hash[symbols.zip(match_data.captures)]
  end


end
