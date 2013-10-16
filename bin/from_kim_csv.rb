#!/usr/bin/env ruby

require 'csv'
require 'calendar_builder'
require 'banner_course'

calendar = CalendarBuilder.new

CSV.parse(ARGF, :headers => true) do |row|
 course = BannerCourse.from_csv_row(row)
 calendar.add_course_session(course)
end

print calendar.to_ical
