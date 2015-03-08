require 'time'
require 'open-uri'
require 'pry'
require 'ostruct'

require_relative 'lib/google_calendar'
require_relative 'lib/base32/base32'
require_relative 'lib/ical_to_gcal'
require_relative 'config'

module Act

  class Sync

    def initialize(calendar_id, ical_file, debug=false)
      @client_id = Config::CLIENT_ID
      @secret = Config::SECRET
      @token_file = File.expand_path Config::TOKEN_FILE # remove this file to re-generate token
      @calendar_id = calendar_id
      @ical_file = ical_file
      @debug = debug
      #
      # Create an instance of google calendar.
      #
      raise "missing option calendar_id" if @calendar_id.nil?

      @ical = get_i_cal
      check_token
    end

    #
    # Return a Google Calendar Instance
    #
    def g_cal
      @g_cal ||= Google::Calendar.new(
        :client_id     => @client_id,
        :client_secret => @secret,
        :calendar      => @calendar_id,
        :redirect_url  => "urn:ietf:wg:oauth:2.0:oob" # this is what Google uses for 'applications'
      )
    end

    def flatten(a)
      return (a.respond_to? :join) ? a.join : a
    end

    def normalize(s)
      flatten(s)
    end

    #
    # Generate an id compatile with Google API
    #
    def gen_id(i_cal_evt)
      return Base32.encode(i_cal_evt.uid.to_s + i_cal_evt.recurrence_id.to_s +  i_cal_evt.sequence.to_s)
    end

    #
    # Find an event by ID
    #
    def find_g_event_by_id(events, id)
      events.find { |e| e.id == id }
    end

    #
    # Return a ICS Calendar Instance
    #
    def get_i_cal
      begin
        file_content = open(@ical_file) { |f| f.read }
        icals = Icalendar.parse(file_content)
        puts "Can't proccess ICS file with multiple calendars" && exit(1) if icals.size > 1
        icals.first
      rescue StandardError
        raise ArgumentError.new("Cannot open #{@ical_file}")
      end
    end

    #
    # Test for equality between ICal and GCal instance
    # Used to determine if an event was updated
    #
    def events_are_equal?(a, b)
      return false if a.id != b.id
      return false if a.title != b.title
      return false if a.status != b.status
      return false if a.description != b.description
      return false if a.location != b.location
      return false if a.transparency != b.transparency
      return false if a.start_time != b.start_time
      return false if a.end_time != b.end_time
      #a.attendees ||= []
      #b.attendees ||= []
      #if a.attendees && b.attendees
        #return false if a.attendees.size != b.attendees.size
        #a.attendees.sort! { |m, n| m['email'] <=> n['email'] }
        #b.attendees.sort! { |m, n| m['email'] <=> n['email'] }
        #a.attendees.zip(b.attendees).each do |m, n|
          #return false if m['email'] != n['email']
          #return false if m['responseStatus'] != n['responseStatus']
        #end
      #else # one nil and not the other
        #return false
      #end
      return true
    end


    #
    # Check oauth2.0 refresh token.
    # If token_file do not exist, request a new token and ask user for authentication
    #
    def check_token
      if File.exist?(@token_file)
        refresh_token = open(@token_file) { |f| f.read }
        g_cal.login_with_refresh_token(refresh_token)
      else
        # A user needs to approve access in order to work with their calendars.
        puts "Visit the following web page in your browser and approve access."
        puts g_cal.authorize_url
        puts "\nCopy the code that Google returned and paste it here:"

        # Pass the ONE TIME USE access code here to login and get a refresh token that you can use for access from now on.
        refresh_token = g_cal.login_with_auth_code($stdin.gets.chomp)

        # Save token to TOKEN_FILE
        File.open(@token_file, 'w') { |f| f.write(refresh_token) }
        puts "Token saved to #{@token_file}"
      end
    end

    #
    # Remove all events instance in GCal. Internally set status to 'cancelled' by google.
    #
    def purge
      i = 0
      debug "Purge events on GCal... "
      events = g_cal.events_all
      events.each do |e|
        next if e.status == 'cancelled'
        debug "Delete: #{e}"
        e.delete
        i += 1
      end
      debug "Done. #{i} event(s) deleted."
      i
    end

    #
    # Return an attendees array compatible with G API
    #
    def parse_attendees(att)
      return nil if att.nil? || att.empty?
      response_status_values = {
        'NEEDS-ACTION' => 'needsAction',
        'ACCEPTED' => 'accepted',
        'DECLINED' => 'declined',
        'TENTATIVE' => 'tentative'
      }
      parsed = att.map do |a|
        ical_str = a.to_ical('string')
        attendee = {}
        /EMAIL=(.*?)(?:;|\Z)/.match(ical_str) do |m|
          attendee['email'] = m.captures[0] && m.captures[0].downcase
        end
        # email required for google
        next unless attendee['email']
        /CN=(.*?)(?:;|\Z)/.match(ical_str) do |m|
          attendee['displayName'] = m.captures[0]
        end
        /PARTSTAT=(.*?)(?:;|\Z)/.match(ical_str) do |m|
          value = response_status_values[m.captures[0]]
          attendee['responseStatus'] = value
        end
        attendee['responseStatus'] = 'needsAction' if attendee['responseStatus'].nil?
        attendee
      end
      parsed.any? ? parsed.compact : nil
    end

    #
    # Create GCal event from ICal event
    #
    def g_evt_from_i_evt(i_evt, g_evt)
      g_evt ||= Google::Event.new
      g_evt.id = gen_id i_evt
      g_evt.title = normalize(i_evt.summary) # if i_evt.respond_to? :summary
      #g_evt.attendees = parse_attendees(i_evt.attendee)
      g_evt.description = normalize(i_evt.description)
      g_evt.start_time = Time.parse(i_evt.dtstart.value_ical)
      g_evt.end_time = Time.parse(i_evt.dtend.value_ical) if i_evt.dtend
      g_evt.transparency = normalize i_evt.transp
      g_evt.status = i_evt.status ? normalize(i_evt.status.downcase) : 'confirmed'
      g_evt.location = normalize i_evt.location
      g_evt
    end

    #
    # Verbose output
    #
    def debug(s)
      return unless @debug
      puts s
    end


    #
    # Debugging function
    #
    def compare_debug(a, b)
      puts "---"
      puts "id #{a.id}"
      puts "id #{b.id}"
      puts "desc #{a.description}"
      puts "desc #{b.description}"
      puts "status #{a.status}"
      puts "status #{b.status}"
      puts "title #{a.title}"
      puts "title #{b.title}"
      puts "start_time #{a.start_time}"
      puts "start_time #{b.start_time}"
      puts "end_time #{a.end_time}"
      puts "end_time #{b.end_time}"
      #puts "attendess a #{a.attendees}"
      #puts "attendess b #{b.attendees}"
      #puts "attendees a - b:#{a.attendees - b.attendees}" if a.attendees && b.attendees
      #puts "attendees a count :#{a.attendees.size}" if a.attendees
      #puts "attendees b count :#{b.attendees.size}" if b.attendees
      puts "---"
    end

    #
    # Core funcion
    #
    def sync

      idem = created = updated = restored = removed = 0
      # load Google events from API, including deleted.
      g_events = g_cal.events_all

      @ical.events.each do |i_evt|
        mock = g_evt_from_i_evt(i_evt, Google::Event.new) # mock object for comparison
        # Pick a Google event by ID from google events
        # and remove it from the list
        g_evt = g_events.find { |e| e.id == mock.id }
        g_events.reject! { |e| e.id == g_evt.id } if g_evt
        begin
          if g_evt # Event found
            if !events_are_equal?(mock, g_evt)
              if g_evt.status == 'cancelled'
                debug('Restored: ')
                restored += 1
              else
                debug('Updated :')
                updated += 1
              end
              g_evt_from_i_evt(i_evt, g_evt)
              debug g_evt
              g_evt.save
            else
              idem +=1
            end
          else # Element not found, create
            created += 1
            g_evt = g_evt_from_i_evt(i_evt, g_evt)
            g_evt.calendar = g_cal
            g_evt.save
            debug "Created #{g_evt}"
          end
        rescue Google::HTTPRequestFailed => msg
          p msg
        rescue Google::HTTPQuotaExceeded => msg
          p msg
          #puts "Try saving without attendees: #{g_evt}"
          #g_evt.attendees = nil
          #g_evt.save
        end
      end

      # Delete remaining Google events
      g_events.each do |e|
        if e.status != 'cancelled'
          debug "Delete: #{e}"
          e.delete
          removed += 1
        end
      end

      puts "ICAL size: #{@ical.events.size}"
      puts "Idem size: #{idem}"
      puts "Created size: #{created}"
      puts "Updated size: #{updated}"
      puts "Restored size: #{restored}"
      puts "Removed size: #{removed}"
      puts "Idem + Created + Updated + Restored: #{idem + created + updated + restored}"
      {idem: idem, created: created, updated: updated, restored:restored, removed: removed, sum: idem + created + updated + restored}
    end
  end
end
