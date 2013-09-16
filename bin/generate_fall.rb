#!/usr/bin/env ruby

require 'calendar_builder'

#
# Specifies a list of files to create, and all of the 
#
courses = {

  #Common core.
  'ece_sophomore' => ['EECE 251', 'EECE 281', 'MATH 371', 'CS 211', 'PHYS 132'],
  'ece_junior'    => ['EECE 301', 'EECE 315', 'EECE 382'],
  'ece_senior'    => ['EECE 487'],

  #Electrical engineering.
  'ee_junior'  => ['EECE 332', 'MATH 323'],

  #Computer engineering.
  'coe_junior' => ['EECE 351', 'MATH 314'],
  'coe_senior' => ['CS 311']

}

#Change to the output directory.
Dir.chdir('output')

#Convert each of the courses above to an ICS file in the current directory.
courses.each do |filename, course_list|
  File.write("#{filename}.ics", CalendarBuilder.from_course_list(*course_list).to_ical)
end
