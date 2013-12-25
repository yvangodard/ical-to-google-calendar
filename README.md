iCal-to-GoogleCalendar (iCal2Gcal)
============

Description
------------
A simple Perl script to parse an iCal-format (.ics) file, and update a Google Calendar with it, via the Google Calendar API.


Bug report
-------------
If you want to submit a bug ticket : [submit bug ticket](https://github.com/ygodard/ical-to-google-calendar/issues).


Why ?
-------------
Why not just add the iCal feed URL to Google Calendar and let them handle it?

Because they update horribly slowly (expect about once every 24 hours).

Calendaring is a time-sensitive thing; I don't want to wait a full day for updates to take effect (by the time Google re-fetch the feed and update my calendar, it could be too late!).

Installation
---------

Pour installer cet outil, depuis votre terminal :

	git clone https://github.com/yvangodard/ldap2mailman.git ; 
	sudo chmod -R 750 ldap2mailman


Configuration
-------
The script will read your Google account details from `~/.netrc`, where you
should specify them as e.g.:

    machine calendar.google.com
    login yourgoogleusername
    password supersecretpassword

You can specify many configurations in your `~/.netrc`.
Of course, you'll want to ensure that file is well protected (chmod 600).

Usage
-------

    ./ical-to-gcal.pl --calendar='Calendar Name' --ical_url=ical_url --configmachine=calendar.google.com

The script will fetch the iCal calendar feed, then for each event in it,
add/update an event in your Google Calendar (the ID from the iCal feed is added in the extra data of the event in the Google Calendar, so the script can match them up next time).

The calendar name you provide must already exist in your Google Calendar
account.

The script adds a tag to each event's content to store the UID of the event
imported from the iCal feed so that events can be updated in future, or deleted if they are no longer present in the source iCal feed.  If you remove this tag from an event, a new (duplicate) event will be created next time the script runs (and the old event will be "orphaned") - so don't do that.


License
-------

Author David Precious <davidp@preshweb.co.uk> | Mod by [Yvan GODARD](http://www.yvangodard.me) <godardyvan@gmail.com>.

Original script : <https://github.com/bigpresh/ical-to-google-calendar>

This script is licensed under Creative Commons 4.0 BY NC SA.

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0"><img alt="Licence Creative Commons" style="border-width:0" src="http://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a>


Limitations
-----------

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.