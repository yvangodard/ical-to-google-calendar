iCal-to-GoogleCalendar (iCal2Gcal)
============

Description
------------
This tool is designed to synchronize an iCal-format (.ics) calendar to a a Google Calendar with it, via the Google Calendar API.

For that, it downloads the ics file, parse it with a cleaner script to avoid incompatibily with Google (with a python Script), and a simple Perl script parse the cleaned file, and updates a Google Calendar with it, via the Google Calendar API (only one way).

This tool includes some third-party scripts:

- ical-to-gcal.py: Original version by Keith McCammon available from [http://mccammon.org/keith/](http://mccammon.org/keith/code) modded by Mario Aeby, [http://eMeidi.com](http://eMeidi.com), [https://github.com/emeidi/ical-to-gcal/blob/master/ical-to-gcal.py](https://github.com/emeidi/ical-to-gcal/blob/master/ical-to-gcal.py)

- ical-to-gcal.pl: Original version by David Precious available form [https://github.com/bigpresh/ical-to-google-calendar](https://github.com/bigpresh/ical-to-google-calendar), modded to work with this tool by Yvan Godard, [https://github.com/yvangodard/ical-to-google-calendar/blob/master/ical-to-gcal.pl](https://github.com/yvangodard/ical-to-google-calendar/blob/master/ical-to-gcal.pl)


Bug report
-------------
If you want to submit a bug ticket : [submit bug ticket](https://github.com/ygodard/ical-to-google-calendar/issues).


Installation
---------

	git clone https://github.com/yvangodard/ical-to-google-calendar.git ; 
	sudo chmod -R 750 ical-to-google-calendar



Help?
-------

    ./ics-sync.sh -h



License
-------

Script by [Yvan GODARD](http://www.yvangodard.me) <godardyvan@gmail.com>.

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