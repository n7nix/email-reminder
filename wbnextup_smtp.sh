#!/bin/bash
#
# File: wbnextup_smtp
#  - for WhiteBox biweekly Net Control reminder
#
# List of Net Control Stations
#   KE7KMK Sheriffs Dispatch
#   KE7KML Lopez Fire
#   KE7KMM ICV
#   KE7KMN Mullis Fire/SJC EOC
#   KE7KMO Orcas Fire
#   PIMC   Peace Island Medical Center
#
## crontab - example cron table follows:
# 31   4  1-6,14-20   *  * [ `date +\%u` -eq 1 ] && /bin/bash /home/$user/bin/wbnextup_smtp.sh -
# 31   4  7-13,21-27  *  * [ `date +\%u` -eq 1 ] && /bin/bash /home/$user/bin/wbnextup_smtp.sh
#
# Changed group email address:
#  from: sjcacs@groups.io
#  to: AuxComm@SJCARS.groups.io
DEBUG=

scriptname="`basename $0`"

user=$(whoami)

# These variables are kept in $email_cfgfile
SYSOP_EMAIL=
DEBUG_EMAIL_LIST=
LOPEZ_EMAIL_LIST=
GOOGLE_EMAIL_LIST=

# Remove ICV from rotation
#WB_ARRAY=("KopShop" "Lopez" "ICV" "Mullis" "Orcas" "Peace Island")
WB_ARRAY=("KopShop" "Lopez" "Mullis" "Orcas" "Peace Island")

# configuration file, has email lists
email_cfgdir="/etc/emailremind"
email_cfgfile="$email_cfgdir/whiteboxlist.txt"

# tmp files
tmpdir="/home/$user/tmp"
WBLASTFILE="$tmpdir/wblast.txt"
WBMSGFILE="$tmpdir/wbmsgfile.txt"
WBLOGFILE="$tmpdir/wblogfile.txt"

# Set white box day to TRUE
WHITEBOX_DAY=1

function dbgecho { if [ ! -z "$DEBUG" ] ; then echo "$*"; fi }

# ==== function getnextup()
# find the next whiteBox station to be net control
# arg = name of last whitebox net control

getnextup() {

lastup="$1"
# Get number of WhiteBox stations
wblen=${#WB_ARRAY[@]}
for ((i = 0; i < $wblen; i++)) ; do

   if [ "$lastup" == "${WB_ARRAY[$i]}" ] ; then
     break;
   fi
done;

case $i in
   5)
      echo "Error nextup not found, lastup: $lastup"
      rm $WBLASTFILE
      nextup="${WB_ARRAY[$i]}"
      return 1
   ;;
   4)
       nextup="${WB_ARRAY[0]}"
   ;;
   *)
       let i=i+1
       nextup="${WB_ARRAY[$i]}"
   ;;
esac

echo "getnextup exit: $nextup"
return 0
}

# ==== function make_cc_list
# mutt needs a '-c' in front of each address

make_cc_list() {

email_list="$1"
dbgecho "make_cc_list arg: $email_list"

i=0
for address in `echo $email_list` ; do
   cc_array[i]="-c $address"
   let i=i+1
done
dbgecho "make_cc_list array: ${cc_array[@]}"
}

# ==== function send_email()
# send mail msg

send_email() {

wb_email_list="$1"

if [ ! -z "$DEBUG" ] ; then
# For test purposes send email to SYSOP & DEBUG_EMAIL_LIST
   echo "subject: $subject"
   echo "message: "
   cat $WBMSGFILE
   dbgecho "DEBUG: Sending to $SYSOP_EMAIL CCing: $DEBUG_EMAIL_LIST"
   dbgecho "DEBUG: Would have sent to: $wb_email_list"
   make_cc_list "$DEBUG_EMAIL_LIST"
   dbgecho "Check cc_list: ${cc_array[@]}"
   dbgecho mutt line: "$subject" ${cc_array[@]} $SYSOP_EMAIL
   mutt  -s "$subject" ${cc_array[@]} $SYSOP_EMAIL < $WBMSGFILE

else
# Send to all whitebox participants plus the SYSOP
    echo "REAL: Sending to $SYSOP_EMAIL CCing: $wb_email_list"
    make_cc_list "$wb_email_list"
    echo "Check cc_list: ${cc_array[@]}"
    mutt  -s "$subject" ${cc_array[@]} $SYSOP_EMAIL < $WBMSGFILE
fi

return
}

# ==== function whitebox_mail()
# Generate a whitebox msg & subject

whitebox_mail() {

# Initialize $lastup to a null string
lastup=

# Find nextup
if [ -e $WBLASTFILE ] ; then
   lastup="$(cat $WBLASTFILE)"
   getnextup "$lastup"
   if [ $? -ne 0 ] ; then
      echo "Error could not get nextup (last: $lastup, next: $nextup)"
      exit 1
   fi

else
   echo "file: $WBLASTFILE does not exist, initializing"
   nextup="${WB_ARRAY[0]}"
fi

if [ -z "$nextup" ] ; then
   echo "Failed to get Nextup, lastup: $lastup"
   exit 1
fi

# Update the state of who is next
#  if DEBUG is not defined
if [ -z "$DEBUG" ] ; then
   echo "$nextup" > $WBLASTFILE
fi

echo "nextup is: $nextup"
tomorrow=$(date --date="next-tuesday" '+%a %b %d')

ntdom=$(date --date="next-tuesday" '+%-d')
# Get rid of leading 0's
ntdom=$((10#$ntdom))
if ((ntdom >= 8 && ntdom <= 14)) || ((ntdom >= 22 && ntdom <= 28)) ; then
   echo "dom verification pass: dom: $ntdom"

{
   echo
   echo "This is a bot message for the WhiteBox drill ..."
   echo
   echo "Hey $nextup,"
   echo
   echo " You are net control for the WhiteBox drill tomorrow $tomorrow @ 9:30am"
   echo " Please post the POD (Plan Of the Day) on 2m JNBBS (NET16)"
   echo " and 220 (NET21) if available."
   echo
} > $WBMSGFILE

   {
       echo "RMS Gateway Packet Connection Summary for N7NIX"
   } >> $WBMSGFILE

   $HOME/bin/show_log.sh -p week >> $WBMSGFILE
   {
       echo
       echo "/N7NIX bot"
   } >> $WBMSGFILE
   # form the subject
   subject=$(echo "White Box Net Control - $nextup")
else
   echo "dom verification fail: dom: $ntdom"
   # form the subject
   subject=$(echo "White Box Net Control - bot failed on dom verification")
   if [ -z "$DEBUG" ] ; then
      # On error, reset last up file
      echo "$lastup" > $WBLASTFILE
      exit 1
   fi
fi

}

# ==== function altweek_mail()
# generate an alternate week msg & subject

altweek_mail() {

tomorrow=$(date --date="next-tuesday" '+%a %b %d')

ntdom=$(date --date="next-tuesday" '+%d')
# Get rid of leading 0's
ntdom=$((10#$ntdom))
if ((ntdom >= 1 && ntdom <= 7)) || ((ntdom >= 15 && ntdom <= 21)) ; then
   echo "dom verification pass: dom: $ntdom"

{
   echo "Hi"
   echo
   echo "This is a bot for the off week WhiteBox drill ..."
   echo "bot runs on machine: $(uname -a)"
   echo
   echo "There is no Whitebox drill tomorrow $tomorrow @9:30!!"
   echo
   echo "Please delete this email."
   echo
   echo "/N7NIX bot"
} > $WBMSGFILE

   # form the subject
   subject=$(echo "No White Box tomorrow")
else
   echo
   echo " == dom verification fail: dom: $ntdom =="
   subject=$(echo "No White Box tomorrow - bot failed on dom verification")
   if [ -z "$DEBUG" ] ; then
      exit 1
   fi
fi
}

# ==== Main

# Is mutt installed?

type -P mutt &>/dev/null
if [ $? -ne 0 ] ; then
  echo "$scriptname: Need to Install mutt package"
  exit 1
fi

# Does tmp dir exist?
if [ ! -d "$tmpdir" ] ; then
   mkdir -p "$tmpdir"
fi

# Does email reminder cfg file exist?"
if [ ! -f "$email_cfgfile" ] ; then
   echo "Need to create email reminder config file: $email_cfgfile"
   exit 1
fi

# Read configuration file for email lists
SYSOP_EMAIL=$(grep "SYSOP_EMAIL" $email_cfgfile | cut -d"=" -f2)
DEBUG_EMAIL_LIST=$(grep "DEBUG_EMAIL_LIST" $email_cfgfile | cut -d"=" -f2)
LOPEZ_EMAIL_LIST=$(grep "LOPEZ_EMAIL_LIST" $email_cfgfile | cut -d"=" -f2)
GOOGLE_EMAIL_LIST=$(grep "GOOGLE_EMAIL_LIST" $email_cfgfile | cut -d"=" -f2)
WB_EMAIL_LIST="$GOOGLE_EMAIL_LIST"

if [ -z "$SYSOP_EMAIL" ] ; then
   echo "Sysop email address not configured"
   SYSOP_EMAIL="$user@$(hostname)"
fi
echo "Using SYSOP_EMAIL: $SYSOP_EMAIL"

if [ -z "$DEBUG_EMAIL_LIST" ] && [ ! -z "$DEBUG" ] ; then
   echo "Debug is enabled but DEBUG_EMAIL_LIST is not defined."
   exit 1
else
   echo "Using DEBUG_EMAIL_LIST: $DEBUG_EMAIL_LIST"
fi

if [ -z "$LOPEZ_EMAIL_LIST" ] ; then
   echo "Lopez email list has not been configured in $email_cfgfile"
   exit 1
else
   echo "Using LOPEZ_EMAIL_LIST: $LOPEZ_EMAIL_LIST"
fi

if [ -z "$GOOGLE_EMAIL_LIST" ] ; then
   echo "Google email list has not been configured in $email_cfgfile"
else
   echo "Using GOOGLE_EMAIL_LIST: $GOOGLE_EMAIL_LIST"
fi

if [ -z "$WB_EMAIL_LIST" ] ; then
   echo
   echo "WhiteBox email problem"
   echo
   exit 1
else
   echo "Using WB_EMAIL_LIST: $WB_EMAIL_LIST"
fi

if [[ $# -gt 0 ]] ; then
   case "$1" in
      test)
         # Set debug flag
         DEBUG=1
	 echo "Debug flag set, ARGS on command line: $#"
      ;;
      alt)
         # Set alt whitebox flag
         WHITEBOX_DAY=0
      ;;
      *)
         echo "Usage: $scriptname <test|alt>"
	 exit 3
      ;;
   esac
fi

#  - send email on 2nd & 4th Mon. for Whitebox
#  - send email on 1st & 3rd Mon. for alt week meetings
# if there are any args then use alt week mail msg

# Generate appropriate email message
if [[ $WHITEBOX_DAY == 1 ]] ; then
  echo "This is a whitebox day script WHITEBOX_DAY: $WHITEBOX_DAY"
  whitebox_mail
  send_email "$WB_EMAIL_LIST"
else
  echo "This is NOT a whitebox day script WHITEBOX_DAY: $WHITEBOX_DAY"
  altweek_mail
  send_email "$LOPEZ_EMAIL_LIST"
fi

exit 0
