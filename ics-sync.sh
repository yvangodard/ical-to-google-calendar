#!/bin/bash

SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
# Thanks to https://github.com/emeidi/ical-to-gcal | cf. Etape 3 http://www.yvangodard.me/synchroniser-plusieurs-fichiers-ics-ical-avec-des-calendriers-google-agenda
PYTHON_ICS_CLEANER=${SCRIPT_DIR}/cleaner-ics-to-gcal.py
# Thanks to https://github.com/bigpresh/ical-to-google-calendar | need some modifications => https://github.com/yvangodard/ical-to-google-calendar
# Cf. cf. Etape 2 http://www.yvangodard.me/synchroniser-plusieurs-fichiers-ics-ical-avec-des-calendriers-google-agenda
PERL_SYNC_SCRIPT=${SCRIPT_DIR}/ical-to-gcal.pl
SCR_VERS="1.0"
# cf. Etape 4 http://www.yvangodard.me/synchroniser-plusieurs-fichiers-ics-ical-avec-des-calendriers-google-agenda
CONFIG_FILE=/etc/ics-sync-script.conf
# Répertoire où seront stockés les fichiers ICS en "transit". Ce répertoire doit être joignable via le procoloe HTTP.
PATH_FILES=/home/webserver
OWNER_PATH_ICS=$(stat -c %U $PATH_FILES)
GWNER_PATH_ICS=$(stat -c %G $PATH_FILES)
PATH_ICS=$PATH_FILES/ical
# Emplacement sur le web de votre dossier $PATH_ICS 
WEB_PATH_ICS=http://monserveur.web/ical
DATE_DU_JOUR=$(date)
LOGS_TMP=$(mktemp /tmp/tmp_log_ics_sync.XXXXX)
LOGS_MAIL=$(mktemp /tmp/tmp_log_ics_sync_mail.XXXXX)
LOGS_GEN=/var/log/ics_sync.log
MAIL_ADMIN="monmail@alerte.com"
MAIL_SENDER="homer@thesimpsons.net"
ERROR_GEN=0
ERROR_FILE=$(mktemp /tmp/tmp_log_ics_sync_error.XXXXX)
ERROR=0
FORCEMAIL=0

[ -z "$1" ] || {
   case $1 in
     "-forcemail" )
       FORCEMAIL=1
       ;;
     "-version" )
       echo "${SCRIPT_NAME} version ${SCR_VERS}"
       ;;
     * )
   esac
}

## Vérifions que le script soit exécuté par le compte root
if [ `whoami` != 'root' ] 
then
	echo "Ce script doit être utilisé par le compte root. Utilisez SUDO." >&2
exit 1
fi

[ ! -e $LOGS_GEN ] && echo " " >> $LOGS_GEN

# Ouvrons une ligne dans le log temporaire
echo " " >> $LOGS_TMP
echo "****************************** $DATE_DU_JOUR ******************************" >> $LOGS_TMP
echo " " >> $LOGS_TMP

# Par sécurité créons le dossier 
[ ! -d $PATH_ICS ] && mkdir -p $PATH_ICS

# Testons si les éléments de configuration nécessaires sont présents
if [ ! -e $CONFIG_FILE ]; then
	echo "ERREUR : Le fichier de configuration $CONFIG_FILE n'existe pas !!!" >> $LOGS_TMP
	echo  >> $LOGS_TMP
	echo "Voici un exemple de configuration :" >> $LOGS_TMP
	echo "# 	Format des lignes :" >> $LOGS_TMP
	echo "# 	URL_du_calendrier	Nom_fichier		Entree_Config_netrc		Calendar_GCAL" >> $LOGS_TMP
	echo "http://mon.adresse/mon/fichier/ics 	fichier_test	calendar.google.com 	MonCalendrierGooglePro" >> $LOGS_TMP
	echo "https://webmail.reseauenscene.fr/ical/reseauenscene.fr/t.grospiron/Projet%20CultiZer	CultiZer 	calendar.google.com 	CultiZer_Reunions" >> $LOGS_TMP
	echo "https://serveur.reseauenscene.fr/ical/reseauenscene.fr/t.grospiron/Calendrier	TGPro 	calendar.google.com 	Thomas_Grospiron_Pro" >> $LOGS_TMP
    ERROR_GEN=1
elif [ ! -e ~/.netrc ]; then
	echo "ERREUR : Le fichier de configuration ~/.netrc n'existe pas !!!" >> $LOGS_TMP
	echo  >> $LOGS_TMP
	echo "Voici un exemple de configuration :" >> $LOGS_TMP
	echo "machine ftp.freebsd.org" >> $LOGS_TMP
	echo "	login anonymous" >> $LOGS_TMP
	echo "	password edwin@mavetju.org" >> $LOGS_TMP
	echo  >> $LOGS_TMP
	echo "machine myownmachine" >> $LOGS_TMP
	echo "	login myusername" >> $LOGS_TMP
	echo "	password mypassword" >> $LOGS_TMP
    ERROR_GEN=1
# Testons si les sous-scripts sont présents
elif [ ! -e $PYTHON_ICS_CLEANER ]; then
	echo "ERREUR : Le sous-script $PYTHON_ICS_CLEANER n'existe pas !!!" >> $LOGS_TMP
	echo "Installez-le à partir de https://github.com/emeidi/ical-to-gcal et renommez-le correctement." >> $LOGS_TMP
	ERROR_GEN=1
elif [ ! -e $PERL_SYNC_SCRIPT ]; then
	echo "ERREUR : Le sous-script $PERL_SYNC_SCRIPT n'existe pas !!!" >> $LOGS_TMP
	echo "Installez-le à partir de https://github.com/yvangodard/ical-to-google-calendar." >> $LOGS_TMP
	ERROR_GEN=1
else

	cat $CONFIG_FILE | \
	while read URL_CALENDAR LOCAL_FILE NETRC_CONFIG	CALENDAR_GCAL
	do
		ERROR_PART=0
		echo "	--> Traitement de l'URL : $URL_CALENDAR" >> $LOGS_TMP
		echo "" >> $LOGS_TMP

		## Testons si les quatre variables nécessaires sont présentes
		VAR_OK=0
		if [ "1${CALENDAR_GCAL}" = "1" ]; then
			VAR_OK=1
			echo "Erreur : les quatre variables nécessaires ne sont pas présentes." >> $LOGS_TMP && ERROR=1
			echo "Voici un exemple de configuration :" >> $LOGS_TMP
			echo "# 	Format des lignes :" >> $LOGS_TMP
			echo "# 	URL_du_calendrier	Nom_fichier		Entree_Config_netrc		Calendar_GCAL" >> $LOGS_TMP
			echo "http://media.education.gouv.fr/ics/Calendrier_Scolaire_Zone_A.ics        ZONEA        moncompte_googlecalendar_2       VacancesZoneA" >> $LOGS_TMP
			echo "http://media.education.gouv.fr/ics/Calendrier_Scolaire_Zone_B.ics        ZONEB        moncompte_googlecalendar_1       VacancesZoneB" >> $LOGS_TMP
			echo "http://media.education.gouv.fr/ics/Calendrier_Scolaire_Zone_C.ics        ZONE_C_Vacances        moncompte_googlecalendar_1       VacancesZoneC" >> $LOGS_TMP
		fi
		if [ $VAR_OK -eq 0 ]; then
			## Testons si l'URL est correcte
			curl -k -s --head $URL_CALENDAR | head -n 1 | grep "HTTP/1.1 200 OK" > /dev/null 
			URL_OK=$?
			[ $URL_OK -eq 0 ] && echo "URL du calendrier semble OK : $URL_CALENDAR." >> $LOGS_TMP
			[ $URL_OK -ne 0 ] && echo "Problème possible pour accéder à l'URL du calendrier : $URL_CALENDAR." >> $LOGS_TMP

			## Testons si l'entrée dans le fichier ~/.netrc semble correcte
			grep $NETRC_CONFIG ~/.netrc > /dev/null
			GREP_NETRC=$?
			[ $GREP_NETRC -eq 0 ] && echo "Entrée $NETRC_CONFIG du fichier ~/.netrc semble correcte." >> $LOGS_TMP
			[ $GREP_NETRC -ne 0 ] && echo "Entrée $NETRC_CONFIG manquante dans le fichier ~/.netrc." >> $LOGS_TMP && ERROR_PART=1
		else
			ERROR_PART=1
		fi

		## Continuons notre processus si nous n'avons pas rencontré d'erreur
		if [ $ERROR_PART -ne 0 ]; then
			echo "	--> Impossible de continuer le traitement de l'URL : $URL_CALENDAR." >> $LOGS_TMP && ERROR=1
		else
			[ -e ${PATH_ICS}/${LOCAL_FILE}.ics ] && rm ${PATH_ICS}/${LOCAL_FILE}.ics
			[ -e ${PATH_ICS}/${LOCAL_FILE}.gcal.ics ] && rm ${PATH_ICS}/${LOCAL_FILE}.gcal.ics
			curl -k --silent $URL_CALENDAR -o ${PATH_ICS}/${LOCAL_FILE}.ics && chown -R $OWNER_PATH_ICS:$GWNER_PATH_ICS $PATH_ICS
			## Testons si le fichier semble correct (contient BEGIN:VCALENDAR)
			if [ -e ${PATH_ICS}/${LOCAL_FILE}.ics ]; then
				cat ${PATH_ICS}/${LOCAL_FILE}.ics | head -n 10 | grep "BEGIN:VCALENDAR" > /dev/null
				ICS_OK=$?
			else
				ICS_OK=1
			fi
			if [ $ICS_OK -ne 0 ]; then
				echo "Le fichier ${PATH_ICS}/${LOCAL_FILE}.ics ne semble pas être un ICS valide." >> $LOGS_TMP
				echo "	--> Impossible de continuer le traitement de l'URL : $URL_CALENDAR." >> $LOGS_TMP && ERROR=1
			else
				echo "Le fichier ${PATH_ICS}/${LOCAL_FILE}.ics semble correct." >> $LOGS_TMP

				## Préparons le fichier pour la synchro GCAL
				echo "" >> $LOGS_TMP
				echo "Envoi de la commande $PYTHON_ICS_CLEANER ${PATH_ICS}/${LOCAL_FILE}.ics." >> $LOGS_TMP
				echo "" >> $LOGS_TMP
				echo "***********" >> $LOGS_TMP
				$PYTHON_ICS_CLEANER ${PATH_ICS}/${LOCAL_FILE}.ics >> $LOGS_TMP 2>&1
				ERROR_PART2=$?
				echo "***********" >> $LOGS_TMP
				echo "" >> $LOGS_TMP
				if [ $ERROR_PART2 -ne 0 ]; then
					echo "Le fichier ${PATH_ICS}/${LOCAL_FILE}.ics n'a pas été traité correctement par $PYTHON_ICS_CLEANER." >> $LOGS_TMP
					echo "	--> Impossible de continuer le traitement de l'URL : $URL_CALENDAR." >> $LOGS_TMP && ERROR=1
				else
					echo "Le fichier ${PATH_ICS}/${LOCAL_FILE}.ics a été traité correctement par $PYTHON_ICS_CLEANER." >> $LOGS_TMP

					## Continuons notre processus si nous n'avons pas rencontré d'erreur
					echo "" >> $LOGS_TMP
					echo "Envoi de la commande $PERL_SYNC_SCRIPT --calendar=${CALENDAR_GCAL} --ical_url=${WEB_PATH_ICS}/${LOCAL_FILE}.gcal.ics --configmachine=${NETRC_CONFIG}." >> $LOGS_TMP
					echo "" >> $LOGS_TMP
					echo "***********" >> $LOGS_TMP
					/usr/bin/perl $PERL_SYNC_SCRIPT --calendar=${CALENDAR_GCAL} --ical_url=${WEB_PATH_ICS}/${LOCAL_FILE}.gcal.ics --configmachine=${NETRC_CONFIG} >> $LOGS_TMP 2>&1 
					ERROR_PART3=$?
					echo "***********" >> $LOGS_TMP
					echo "" >> $LOGS_TMP
					if [ ${ERROR_PART3} -eq 0 ]; then
						echo "Le fichier ${PATH_ICS}/${LOCAL_FILE}.gcal.ics a été traité correctement par la commande $PERL_SYNC_SCRIPT." >> $LOGS_TMP
					else
						echo "Erreur(s) lors de l'envoi de la commande $PERL_SYNC_SCRIPT." >> $LOGS_TMP
						echo "	--> Impossible de terminer le traitement de l'URL : $URL_CALENDAR." >> $LOGS_TMP && ERROR=1
					fi
				fi
			fi
      	 fi  	
      	 echo "" >> $LOGS_TMP
      	 [ $ERROR -ne 0 ] && echo $ERROR > $ERROR_FILE
	done < $CONFIG_FILE
fi

grep 1 $ERROR_FILE > /dev/null
GREP_ERROR=$?

if [ $ERROR_GEN -ne 0 ]; then
	# envoi du mail
	echo "To: $MAIL_ADMIN" > $LOGS_MAIL
	echo "From: Server ICS SYNC Report <$MAIL_SENDER>" >> $LOGS_MAIL
	echo "Subject: [ERREUR TOTALE] Synchronisation fichiers ICS" - `date` >> $LOGS_MAIL
	cat $LOGS_TMP >> $LOGS_MAIL
	cat $LOGS_MAIL | /usr/sbin/sendmail -f $MAIL_ADMIN -t
	echo "Problème(s) important(s) rencontré(s) lors de l'éxécution de $0" >&2
	cat $LOGS_TMP >> $LOGS_GEN
	rm $LOGS_TMP
	rm $LOGS_MAIL
	rm $ERROR_FILE
	exit 1
elif [ $GREP_ERROR -eq 0 ]; then
	# envoi du mail
	echo "To: $MAIL_ADMIN" > $LOGS_MAIL
	echo "From: Server ICS SYNC Report <$MAIL_SENDER>" >> $LOGS_MAIL
	echo "Subject: [ERREUR PARTIELLE] Synchronisation fichiers ICS" - `date` >> $LOGS_MAIL
	cat $LOGS_TMP >> $LOGS_MAIL
	cat $LOGS_MAIL | /usr/sbin/sendmail -f $MAIL_ADMIN -t
	echo "Problème(s) rencontré(s) lors de l'éxécution de $0" >&2
	cat $LOGS_TMP >> $LOGS_GEN
	rm $LOGS_TMP
	rm $LOGS_MAIL
	rm $ERROR_FILE
	exit 1
elif [ $FORCEMAIL -eq 1 ]; then
	# envoi du mail
	echo "To: $MAIL_ADMIN" > $LOGS_MAIL
	echo "From: Server ICS SYNC Report <$MAIL_SENDER>" >> $LOGS_MAIL
	echo "Subject: Synchronisation fichiers ICS" - `date` >> $LOGS_MAIL
	cat $LOGS_TMP >> $LOGS_MAIL
	cat $LOGS_MAIL | /usr/sbin/sendmail -f $MAIL_ADMIN -t
	cat $LOGS_TMP >> $LOGS_GEN
	rm $LOGS_TMP
	rm $LOGS_MAIL
	rm $ERROR_FILE
	exit 0
fi

cat $LOGS_TMP >> $LOGS_GEN
rm $LOGS_TMP
rm $LOGS_MAIL
rm $ERROR_FILE
exit 0