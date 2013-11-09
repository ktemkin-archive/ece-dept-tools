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

require 'ri_cal'
require 'public_schedule'

#
# Object which assists in the creation of iCalendar 
#
class CalendarBuilder 

  #
  # Represents a default "date range" that should contain any reasonable course dates.
  # If we're still using Banner in the year 3000, we deserve to have to debug this.
  #
  DEFAULT_DATE_RANGE = (DateTime.parse("January 1st, 2000")..DateTime.parse("January 1st 3000"))

  #
  # Initialies a CalendarBuilder.
  # TODO: More intelligently determine the current semester?
  # 
  #def initialize(year = Time.now.year, session=PublicSchedule.current_session, range = DEFAULT_DATE_RANGE, unique = true)
  def initialize(year = 2014, session=:spring, range = DEFAULT_DATE_RANGE, unique = true)

    #Create a new connection to the public schedule of classes, 
    #from which we pull all course information, when needed.
    @schedule_of_classes = PublicSchedule.new(year, session)

    #And start off with 
    @sessions = []

    #Store the date range to work with.
    @range = range

    #Store whether we should be working with unique sessions only.
    @unique = unique

  end

  #
  # Adds a single course session to the calendar.
  #
  def add_course_session(session)
    invalidate_calendar
    @sessions << session
  end

  #
  # Adds all sessions for a set of courses.
  #
  def add_all_sessions_for_courses(*course_list)
    course_list.each { |course| add_course_sessions(course) }
  end

  #
  # Adds a collection of course sessions to the calendar.
  #
  def add_course_sessions(sessions)

    invalidate_calendar
 
    #If this isn't a collection, retrieve all course sessions for the given object.
    sessions = @schedule_of_classes.get_course_sessions(sessions) unless sessions.respond_to?(:each)

    #If we're in unqiue-only mode, merge all similar sections.
    sessions = BannerCourse.merge_similar_sessions(sessions) if @unique

    #Add the courses
    @sessions.push(*sessions)

  end

  #
  # Converts the given CalendarBuilder to an iCal stream.
  #
  def to_ical
    create_internal_calendar
    @calendar.export
  end

  #
  # Convenience function that creates a CalendarBuilder from
  # a list of courses.
  #
  def self.from_course_list(*courses)

    #Create a new bulder, and populate it with all of the requested
    #courses.
    builder = new
    builder.add_all_sessions_for_courses(*courses)

    #Return the builder.
    builder

  end

  private


  #
  # Deletes the currently memoized copy of internal calendar.
  # Should be used whenever a change to the list of sessions occurs.
  #
  def invalidate_calendar
    @calendar = nil
  end

  #
  # Creates the internal calendar which organizes all of the class sessions.
  #
  def create_internal_calendar
   
    #If we have a valid calendar, return it directly.
    return @calender unless @calendar.nil?

    @calendar = RiCal.Calendar do |cal|

      #Ensure that we're not enforcing a time zone.
      cal.default_tzid = :floating

      @sessions.each do |session|

         #Skip any events that don't have dates.
         next unless session.start_time and session.end_time and session.date_range

         add_event_to_calendar(cal, session) 
      end

    end
  end

  #
  # Adds an instance of the given session _at_ t
  #
  def add_event_to_calendar(cal, session)

    #Build a summary of the course, for calendar display.
    summary = "#{session.number} #{session.type} - #{session.name}"

    #If this course has multiple sessions, append that information to the title.
    summary = "#{summary} (#{session.count})" if session.count > 1

    #Add the session event to the calendar.
    cal.event do 
      summary       summary
      dtstart       session.date_range.first + session.start_time
      dtend         session.date_range.first + session.end_time
      location      session.room if session.room
      description   "Instructor: #{session.instructor}\n\nDescription: #{session.description}"

      #And set up a recurrance pattern that includes all of instances of this session.
      rdate(*session.all_session_dates)
    end
  end


  #
  # Yields every relevant course session/time. 
  #
  # range: If a range of DateTimes is provided, filter
  #   so only DateTimes within the range are included.
  # unique: If true, only unique events will be provided.
  #   Courses with the same name at the same time will be ignored.
  #
  def each_session_date(unique=false)

    #Keep track of all pairs of dates and names we've seen.
    seen = {}

    @sessions.each do |session| 
      session.each_session_date do |time|

        #Come up with an identifier that determines if this session is "unique".
        id = session_id(session, time)
        
        #If we've already seen this session, and we're in unique mode, skip it.
        next if seen.has_key?(id) and unique

        #If the given session date is outside of the accepted date range,
        #skip it.
        next unless @range.include?(time)

        #Mark the current session number and time as seen.
        seen[id] = true

        #And yield the current session and time offset.
        yield session, time

      end
    end
  end

  #
  # Return a short ID which different for any sessions
  # which have different session times, session numbers, 
  # and session types; but the same otherwise.
  #
  def session_id(session, time)
    "#{time}#{session.number}#{session.type}"
  end

  


end
