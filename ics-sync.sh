#!/bin/bash

#------------------------------------------#
#           iCal2GoogleCalendar            #
#------------------------------------------#
#                                          #
#  Synchronize an ics calendar to Google   #
#   	  Calendar (one way only)          #
#                                          #
#              Yvan Godard                 #
#          godardyvan@gmail.com            #
#                                          #
#     Version 1.2 -- february, 28 2014     #
#             Under Licence                #
#     Creative Commons 4.0 BY NC SA        #
#                                          #
#          http://goo.gl/AQjEnM            #
#                                          #
#------------------------------------------#

# Variables initialisation

VERSION="iCal2GoogleCalendar v1.2 - 2014, Yvan Godard [godardyvan@gmail.com]"
help="no"
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
PYTHON_ICS_CLEANER=${SCRIPT_DIR}/ics-to-gcal.py
PERL_SYNC_SCRIPT=${SCRIPT_DIR}/ical-to-gcal.pl
URL_CALENDAR=""
LOCAL_FILE=""
NETRC_CONFIG=""
CALENDAR_GCAL=""
PATH_ICS=""
WEB_PATH_ICS=""
CURL_USER=""
CURL_PASS=""
PERL_BIN=/usr/bin/perl
LOG=/var/log/ics_sync.log
LOG_ACTIVE=0
LOG_TEMP=$(mktemp /tmp/tmp_log_ics_sync.XXXXX)
ERROR=0
EMAIL_REPORT="nomail"
EMAIL_LEVEL=0
WITH_USER=0

help () {
	echo -e "$VERSION\n"
	echo -e "This tool is designed to synchronize an iCal-format (.ics) calendar to a a Google Calendar with it, via the Google Calendar API."
	echo -e "For that, it downloads the ics file, parse it with a cleaner script to avoid incompatibily with Google (with a python Script),"
	echo -e "and a simple Perl script parse the cleaned file, and updates a Google Calendar with it, via the Google Calendar API (only one way)."
	echo -e "This tool includes some third-party scripts:"
	echo -e "\t- ical-to-gcal.py: Original version by Keith McCammon available from http://mccammon.org/keith/code"
	echo -e "\t  modded by Mario Aeby, http://eMeidi.com,https://github.com/emeidi/ical-to-gcal/blob/master/ical-to-gcal.py"
	echo -e "\t- ical-to-gcal.pl: Original version by David Precious available form https://github.com/bigpresh/ical-to-google-calendar,"
	echo -e "\t  modded to work with this tool by Yvan Godard, https://github.com/yvangodard/ical-to-google-calendar/blob/master/ical-to-gcal.pl"
	echo -e "\nDisclamer:"
	echo -e "This tool is provide without any support and guarantee."
	echo -e "\nSynopsis:"
	echo -e "./$SCRIPT_NAME [-h] | -c <URL of iCal-format (.ics) file> -n <Calendar temp name> -m <entry name in ~/.netrc> -C <GoogleCalendar Name>"
	echo -e "                     -p <temp path to save ics files> -w <URL of temp path>"
	echo -e "                    [-u <user to access to ics file>] [-P <password to access to ics file>] [-B <perl bin path>]"
	echo -e "                    [-e <email report option>] [-E <email address>] [-j <log file>]"
	echo -e "\n\t-h:                                   prints this help then exit"
	echo -e "\nMandatory options:"
	echo -e "\t-c <URL of iCal-format (.ics) file>:  the URL of iCal-format (.ics) source calendar (i.e.: 'http://my.server.com/path/to/icsfile.ics')"
	echo -e "\t-n <calendar temp name>:              the temp file name of this calendar"	
	echo -e "\t-m <entry name in ~/.netrc>:          the machine entry in ~/.netrc file, with Google login and Google password, as this:"
	echo -e "\t                                           machine my_netrc_entry_name"
	echo -e "\t                                           login logintogoogle@my.server.com"
	echo -e "\t                                           password the_full_password"
	echo -e "\t-C <GoogleCalendar Name>:             the name of the GoogleCalendar you want to sync to. This calendar must be created first."
	echo -e "\t-p <temp path to save ics files>:     the path to save ics files 'in transit'. This path must be reachable via HTTP (i.e.: '/home/user/webserver/ical')"
	echo -e "\t                                      and must exist before using this tool."
	echo -e "\t-w <URL of temp path>:                the URL of the temp path (i.e.: 'http://my.server.com/path/to/icalpath')."
	echo -e "\nOptional options:"
	echo -e "\t-u <user to access to ics file>:      the user to use to connect to the URL of iCal-format (.ics) file (if authentification is needed)."
	echo -e "\t-P <password to access to ics file>:  the  password of user to use to connect to the URL of iCal-format (.ics) file (if authentification is needed),"
	echo -e "\t                                      must be filled if '- u' parameter is used. Asked if not filled."
	echo -e "\t-B <perl bin path>:                   path to Perl bin (default: '${PERL_BIN}')"
	echo -e "\t-e <email report option>:             settings for sending a report by email, must be 'onerror', 'forcemail' or 'nomail' (default: '${EMAIL_REPORT}')"
	echo -e "\t-E <email address>:                   email address to send the report (must be filled if '-e forcemail' or '-e onerror' options is used)"
	echo -e "\t-j <log file>:                        enables logging instead of standard output. Specify an argument for the full path to the log file"
	echo -e "\t                                      (i.e.: '${LOG}') or use 'default' (${LOG})"
	exit 0
}

error () {
	echo -e "\n*** Error ***"
	echo -e ${1}
	echo -e "\n"${VERSION}
	alldone 1
}

alldone () {
	# Redirect standard outpout
	exec 1>&6 6>&-
	# Logging if needed 
	[ ${LOG_ACTIVE} -eq 1 ] && cat ${LOG_TEMP} >> ${LOG}
	# Print current log to standard outpout
	[ ${LOG_ACTIVE} -ne 1 ] && cat ${LOG_TEMP}
	[ ${EMAIL_LEVEL} -ne 0 ] && [ ${1} -ne 0 ] && cat ${LOG_TEMP} | mail -s "[ERROR: ${SCRIPT_NAME}] Processing URL: ${URL_CALENDAR}" "${EMAIL_ADDRESS}" && rm ${LOG_TEMP} && exit ${1}
	[ ${EMAIL_LEVEL} -eq 2 ] && [ ${1} -eq 0 ] && cat ${LOG_TEMP} | mail -s "[OK: ${SCRIPT_NAME}] Processing URL: ${URL_CALENDAR}" "${EMAIL_ADDRESS}" && rm ${LOG_TEMP} && exit ${1}	
	[ ${EMAIL_LEVEL} -eq 2 ] && [ $URL_OK -ne 0 ] && cat ${LOG_TEMP} | mail -s "[POSSIBLE ERROR: ${SCRIPT_NAME}] Processing URL: ${URL_CALENDAR}" "${EMAIL_ADDRESS}" && rm ${LOG_TEMP} && exit ${1}
	rm ${LOG_TEMP}
	exit ${1}
}

optsCount=0

while getopts "hc:n:m:C:p:w:u:P:B:e:E:j:" OPTION
do
	case "$OPTION" in
		h)	help="yes"
						;;
		c)	URL_CALENDAR=${OPTARG}
			let optsCount=$optsCount+1
						;;
		n)	LOCAL_FILE=${OPTARG}
			let optsCount=$optsCount+1
						;;
		m)	NETRC_CONFIG=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
        C)	CALENDAR_GCAL=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
		p)	PATH_ICS=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
        w)	WEB_PATH_ICS=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
	    u) 	CURL_USER=${OPTARG}
			WITH_USER=1
						;;
		P) 	CURL_PASS=${OPTARG}
						;;
		B) 	PERL_BIN=${OPTARG}
						;;
        e)	EMAIL_REPORT=${OPTARG}
                        ;;                             
        E)	EMAIL_ADDRESS=${OPTARG}
                        ;;
        j)	[ ${OPTARG} != "default" ] && LOG=${OPTARG}
			LOG_ACTIVE=1
                        ;;
	esac
done

if [[ ${optsCount} != "6" ]]
	then
        help
        alldone 1
fi

if [[ ${help} = "yes" ]]
	then
	help
fi

if [[ ${WITH_USER} = "1" ]] && [[ ${CURL_PASS} = "" ]]
	then
	echo "Enter password associated to user '${CURL_USER}' needed to access to '${URL_CALENDAR}'?" 
	read -s CURL_PASS
fi

# Redirect standard outpout to temp file
exec 6>&1
exec >> ${LOG_TEMP}

# Start temp log file
echo -e "\n****************************** `date` ******************************\n"
echo -e "\nProcessing URL: ${URL_CALENDAR}\n"

# Test of sending email parameter and check the consistency of the parameter email address
if [[ ${EMAIL_REPORT} = "forcemail" ]]
	then
	EMAIL_LEVEL=2
	if [[ -z $EMAIL_ADDRESS ]]
		then
		echo -e "You use option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t-> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then
    		echo -e "This address '${EMAIL_ADDRESS}' does not seem valid.\n\t-> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} = "onerror" ]]
	then
	EMAIL_LEVEL=1
	if [[ -z $EMAIL_ADDRESS ]]
		then
		echo -e "You use option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t-> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then	
    		echo -e "This address '${EMAIL_ADDRESS}' does not seem valid.\n\t-> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} != "nomail" ]]
	then
	echo -e "\nOption '-e ${EMAIL_REPORT}' is not valid (must be: 'onerror', 'forcemail' or 'nomail').\n\t-> We continue the process without sending email."
	EMAIL_LEVEL=0
elif [[ ${EMAIL_REPORT} = "nomail" ]]
	then
	EMAIL_LEVEL=0
fi

# Test if ~/.netrc exists
if [ ! -e ~/.netrc ]
	then
	error "Config file '~/.netrc' doesn't exist!\nHere is a sample '~/.netrc' config file:\n\tmachine ftp.freebsd.org\n\tlogin anonymous\n\tpassword edwin@mavetju.org\n\n\tmachine myownmachine\n\tlogin myusername\n\tpassword mypassword"
fi

# Installing $PYTHON_ICS_CLEANER if needed
if [ ! -f ${PYTHON_ICS_CLEANER} ] 
	then
	echo -e "\nInstalling ${PYTHON_ICS_CLEANER}..."
	wget -O ${PYTHON_ICS_CLEANER} --no-check-certificate https://raw.github.com/yvangodard/ical-to-google-calendar/master/ical-to-gcal.py
	if [ $? -ne 0 ] 
		then
		ERROR_MESSAGE=$(echo $?)
		error "Error while downloading https://raw.github.com/yvangodard/ical-to-google-calendar/master/ical-to-gcal.py.\n${ERROR_MESSAGE}.\nYou need to solve this before re-launching this tool."
	else
		echo -e "\t-> Installation OK"
		chmod +x ${PYTHON_ICS_CLEANER}
	fi
fi

# Installing $PERL_SYNC_SCRIPT if needed
if [ ! -f ${PERL_SYNC_SCRIPT} ] 
	then
	echo -e "\nInstalling ${PERL_SYNC_SCRIPT}..."
	wget -O ${PERL_SYNC_SCRIPT} --no-check-certificate https://raw.github.com/yvangodard/ical-to-google-calendar/master/ical-to-gcal.pl
	if [ $? -ne 0 ] 
		then
		ERROR_MESSAGE_1=$(echo $?)
		error "Error while downloading https://raw.github.com/yvangodard/ical-to-google-calendar/master/ical-to-gcal.pl.\n${ERROR_MESSAGE_1}.\nYou need to solve this before re-launching this tool."
	else
		echo -e "\t-> Installation OK"
		chmod +x ${PERL_SYNC_SCRIPT}
	fi
fi

## Testons si l'URL est correcte
if [[ ${WITH_USER} = "0" ]] 
	then
	curl -k -s --head ${URL_CALENDAR} | head -n 1 | grep "HTTP/1.1 200 OK" > /dev/null
	URL_OK=$?
elif [[ ${WITH_USER} = "1" ]]
	then
	curl -k -s -u ${CURL_USER}:${CURL_PASS} --head ${URL_CALENDAR} | head -n 1 | grep "HTTP/1.1 200 OK" > /dev/null
	URL_OK=$?
fi
[ $URL_OK -eq 0 ] && echo "URL of ics calendar seems to be OK: ${URL_CALENDAR}."
[ $URL_OK -ne 0 ] && echo "Possible problem to access to ics calendar: ${URL_CALENDAR}."

## Test if '~/.netrc' entry exists
grep ${NETRC_CONFIG} ~/.netrc > /dev/null
GREP_NETRC=$?
[ $GREP_NETRC -eq 0 ] && echo "This entry '${NETRC_CONFIG}' in '~/.netrc' seems to be correct."
[ $GREP_NETRC -ne 0 ] && error "This entry '${NETRC_CONFIG}' in '~/.netrc' doesn't exist."

# Test if temp path exists
[ ! -d ${PATH_ICS} ] && error "The temp path '${PATH_ICS}' is not correct."
OWNER_PATH_ICS=$(stat -c %U ${PATH_ICS})
GWNER_PATH_ICS=$(stat -c %G ${PATH_ICS})

# Removing old files
[ -e ${PATH_ICS}/${LOCAL_FILE}.ics ] && rm ${PATH_ICS}/${LOCAL_FILE}.ics
[ -e ${PATH_ICS}/${LOCAL_FILE}.gcal.ics ] && rm ${PATH_ICS}/${LOCAL_FILE}.gcal.ics

# Downloading ics file
if [[ ${WITH_USER} = "0" ]] 
	then
	curl -k --silent ${URL_CALENDAR} -o ${PATH_ICS}/${LOCAL_FILE}.ics && chown -R ${OWNER_PATH_ICS}:${GWNER_PATH_ICS} ${PATH_ICS}
elif [[ ${WITH_USER} = "1" ]]
	then
	curl -k --silent -u ${CURL_USER}:${CURL_PASS} ${URL_CALENDAR} -o ${PATH_ICS}/${LOCAL_FILE}.ics && chown -R ${OWNER_PATH_ICS}:${GWNER_PATH_ICS} ${PATH_ICS}
fi

## Test if file seems to be correct (contains BEGIN:VCALENDAR)
if [ -e ${PATH_ICS}/${LOCAL_FILE}.ics ]
	then
	cat ${PATH_ICS}/${LOCAL_FILE}.ics | head -n 10 | grep "BEGIN:VCALENDAR" > /dev/null
	[ $? -ne 0 ] && error "File '${PATH_ICS}/${LOCAL_FILE}.ics' doesn't seem to be a correct calendar file."
else
	error "File ${PATH_ICS}/${LOCAL_FILE}.ics doesn't exist"
fi

# Processing by ${PYTHON_ICS_CLEANER}
echo -e "\nProcessing command: '${PYTHON_ICS_CLEANER} ${PATH_ICS}/${LOCAL_FILE}.ics'."
echo -e "\n***********"
${PYTHON_ICS_CLEANER} ${PATH_ICS}/${LOCAL_FILE}.ics 2>&1
[ $? -ne 0 ] && error "File processing on '${PATH_ICS}/${LOCAL_FILE}.ics' was not completed successfully by '${PYTHON_ICS_CLEANER}'."
echo -e "***********\n"
echo -e "File processing on '${PATH_ICS}/${LOCAL_FILE}.ics' was completed successfully by '${PYTHON_ICS_CLEANER}'.\n"

# Processing by ${PERL_SYNC_SCRIPT}
echo "Processing commmand: '${PERL_SYNC_SCRIPT} --calendar=${CALENDAR_GCAL} --ical_url=${WEB_PATH_ICS}/${LOCAL_FILE}.gcal.ics --configmachine=${NETRC_CONFIG}'."
echo -e "\n***********"
${PERL_BIN} ${PERL_SYNC_SCRIPT} --calendar=${CALENDAR_GCAL} --ical_url=${WEB_PATH_ICS}/${LOCAL_FILE}.gcal.ics --configmachine=${NETRC_CONFIG} 2>&1
[ $? -ne 0 ] && error "Errors when using ${PERL_SYNC_SCRIPT}"
echo -e "***********\n"
echo -e "The file '${PATH_ICS}/${LOCAL_FILE}.gcal.ics' has been successfully processed by the script '${PERL_SYNC_SCRIPT}'."

alldone 0