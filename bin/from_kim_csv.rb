#!/usr/bin/env ruby

require 'csv'
require 'calendar_builder'
require 'banner_course'

#
# Specifies a list of files to create, and all of the courses that should be included.
#
Courses = {

  #Common core.
  'ece_sophomore' => ['CS 212', 'ISE 261', 'EECE 260', 'EECE 287'],
  'ece_junior'    => ['EECE 387'],
  'ece_senior'    => ['EECE 488'],

  #Electrical engineering.
  'ee_junior'  => ['EECE 323', 'EECE 361', 'EECE 377'],

  #Computer engineering.
  'coe_junior' => ['EECE 352', 'EECE 359'],
  'coe_senior' => [],

  #Others
  'other' => []

}

#
# Returns the name of the calendar for which a course should belong.
#
def calendar_for_course(course, default='other')

  #Find the calendar that should contain a given course.
  name, calendar = Courses.find { |name, value| value.include?(course) }

  #If no calendar should contain this course, provide the default value.
  name || default

end

#Create a new hash of calendar files.
calendars = {}

#And convert each of the years into a CalendarBuilder.
Courses.each do |year, courses| 
 calendars[year] = CalendarBuilder.new
end

#Parse the given CSV file...
CSV.parse(ARGF, :headers => true) do |row|

 #Extract the given course...
 course = BannerCourse.from_csv_row(row)

 #Determine which calendar the course belongs to.
 calendar = calendar_for_course(course.number)

 #Add the course to the given calendar.
 calendars[calendar].add_course_session(course)
end


#Convert each of the courses above to an ICS file in the current directory.
Courses.each do |calendar, course_list|
  File.write("#{calendar}.ics", calendars[calendar].to_ical)
end
