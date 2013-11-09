#!/usr/bin/env ruby

require 'calendar_builder'
require 'fileutils'


#
# Specifies a list of files to create, and all of the courses that should be contained.
#
courses = {

  #Common core.
  'ece_sophomore' => ['ISE 261', 'EECE 287', 'EECE 260', 'CS 212'],
  'ece_junior'    => ['EECE 387'],
  'ece_senior'    => ['EECE 488'],

  #Electrical engineering.
  'ee_junior'  => ['EECE 323', 'EECE 361', 'EECE 377'],

  #Computer engineering.
  'coe_junior' => ['EECE 352', 'EECE 359'],

  #Graduate Studens
  'graduate' => %w(503 508 521 522 566X 570 573 575 578X 580A 580D 580F 658A).map { |number| "EECE #{number}"}
}

#Change to the output directory.
FileUtils.mkdir_p('output')
Dir.chdir('output')

#Convert each of the courses above to an ICS file in the current directory.
courses.each do |filename, course_list|
  File.write("#{filename}.ics", CalendarBuilder.from_course_list(*course_list).to_ical)
end
