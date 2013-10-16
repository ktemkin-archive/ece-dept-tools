#!/usr/bin/env ruby

require 'calendar_builder'
require 'fileutils'

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
  'coe_senior' => ['CS 311'],

  #Graduate Studens
  'graduate' => ['EECE 502', 'EECE 504', 'EECE 505X', 'EECE 506', 'EECE 507', 'EECE 510', 'EECE 515', 'EECE 520', 'EECE 530',
                 'EECE 542', 'EECE 545', 'EECE 552', 'EECE 553', 'EECE 560', 'EECE 562', 'EECE 574', 'EECE 580B', 'EECE580E']

}

#Change to the output directory.
FileUtils.mkdir_p('output')
Dir.chdir('output')

#Convert each of the courses above to an ICS file in the current directory.
courses.each do |filename, course_list|
  File.write("#{filename}.ics", CalendarBuilder.from_course_list(*course_list).to_ical)
end
