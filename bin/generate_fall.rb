#!/usr/bin/env ruby

require 'calendar_builder'
require 'fileutils'

#
# Specifies a list of files to create, and all of the 
#
courses = {

  #Common core.
  'spring' => ['EECE 252', 'EECE 260', 'ISE 261', 'CS 212']

}

#Change to the output directory.
FileUtils.mkdir_p('output')
Dir.chdir('output')

#Convert each of the courses above to an ICS file in the current directory.
courses.each do |filename, course_list|
  File.write("#{filename}.ics", CalendarBuilder.from_course_list(*course_list).to_ical)
end
