#!/bin/bash
#
# File: ncnextup_smtp.sh
#  - for SJCARS weekly Net Control reminder
#
## ** Index - used to select net control for the week
# - Index begins at 0
# - Index stored in NCINDEXFILE is reset to zero when
#   it is larger than the number of entries in NCLIST_FILENAME
#   INdex File contains a single integer from: 0 to
#     (number of enteries in NCLIST_FILENAME) - 1
#
## ** Notification
# - Two notifications can be e-mailed
#   - First notification does not bump the NCINDEXFILE
# - Command line arg "next" will bump the INDEX
#
## ** Names of net controllers are maintained on the SJCARS website at
#     SJCARS_NCLIST_URL
#
## ** Links to the roll call list & net preamble text are maintained on
#     the SJCARS website at SJCARS_PREAMBLE_URL
#
## ** Email addresses are maintained in config file
#
## ** Error messages are e-mailed to SYSOP_EMAIL
#
## ** crontabs - example cron table entry follows:
# 5 minutes after 4 on day following SJCARS net (thur), non incrementing index
# 5 4 * * 4 /home/$user/bin/ncnextup.sh
#
# 5 minutes after 4 on day of SJCARS net (wed), increment index
# 5 4 * * 3  /home/$user/bin/ncnextup.sh next
#
# $Id: ncnextup.sh 149 2013-04-18 17:33:53Z gunn $
#
DEBUG=0

scriptname="`basename $0`"

user=$(whoami)

SYSOP_EMAIL=
DEBUG_EMAIL_LIST=
SJCARS_EMAIL_LIST=

SJCARS_PREAMBLE_URL="http://sjcars.org/blog/nets"
SJCARS_NCLIST_URL="http://sjcars.org/blog/ncs-rotation"

NCLIST_HTML_FILENAME="/home/$user/tmp/nclist_html_tmp.txt"
# ncnames.txt gets created from scraping website
NCLIST_FILENAME="/home/$user/tmp/ncnames.txt"
NCLIST_BACKUP_FILENAME="/home/$user/tmp/ncnames_bak.txt"
# ncindex.txt gets created first time script is run
NCINDEXFILE="/home/$user/bin/ncindex.txt"
#NCEMAILFILE="/home/$user/bin/ncemail.txt"
NCMSGFILE="/home/$user/bin/ncmsgfile.txt"
NCERRFILE="/home/$user/bin/ncerrfile.txt"

# configuration file, has email lists
email_cfgdir="/etc/emailremind"
email_cfgfile="$email_cfgdir/whiteboxlist.txt"

# cURL command line
CURL="/usr/bin/curl"
# -s Silient or quiet mode, don't show progress meter
# -S When used with -s makes curl show error msg on failure
# -f Fail silently no output at all on server errors
# -k allow "insecure" SSL connections and transfers
CURLARGS="-fsSk"
USER_AGENT='Mozilla/4.73 [en] (X11; U; Linux 2.2.15 i686)'
#CURLARGS="--user-agent \"$USER_AGENT\" -fsSk"

echo "curl args: $CURLARGS"

# Globals for return values from getfilelinks()
preamble_str="No link found"
rollcall_str="No link found"

function dbgecho { if [ ! -z "$DEBUG" ] ; then echo "$*"; fi }

#
# === file_check
#
file_check() {

if [ ! -e "$NCLIST_FILENAME" ] ; then
  echo "$scriptname: file: $NCLIST_FILENAME does not exist"
fi
if [ ! -e "$NCINDEXFILE" ] ; then
  echo "$scriptname: file: $NCINDEXFILE does not exist"
fi
if [ ! -e "$email_cfgfile" ] ; then
  echo "$scriptname: file: $email_cfgfile does not exist"
fi

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

#
# === function send_email() =================
# generate a mail msg & check for it in outbox
#
send_email() {

# For test purposes just send email to SYSOP
if [ "$DEBUG" -ne "0" ] ; then
    make_cc_list "$DEBUG_EMAIL_LIST"
    dbgecho mutt line: "$subject" ${cc_array[@]} $SYSOP_EMAIL < $NCMSGFILE
    mutt  -s "$subject" ${cc_array[@]} $SYSOP_EMAIL < $NCMSGFILE
else
# Send to next net conntrol on list
    make_cc_list "$SJCARS_EMAIL_LIST"
    echo "REAL: Sending to $nc_email CCing: ${cc_array[@]}"
    mutt  -s "$subject" ${cc_array[@]} $nc_email < $NCMSGFILE
fi

return
}

#
# === function errorhandler() =================
#
function errorhandler ()
{
  subject=$(echo "Error in $scriptname on $(echo `date`)")
  message=$(echo "Error in $scriptname on $(echo `date`): $1")
  echo $message
  echo $message > $NCERRFILE
  mutt  -s "$subject" $SYSOP_EMAIL < $NCERRFILE
}

#
# === function nclist() =================
# Get HTML page that contains the net control list & parse out the name
# & call sign.
#
function nclist ()
{
SearchStrStart="if you&#8217;d like to join.";
SearchStr1="<td valign=\"top\">";

if (( $DEBUG )) ; then
    echo "scrape test nclist"
    echo "URL: $SJCARS_NCLIST_URL"
    echo "Designator: $SearchStrStart"
    echo
fi

echo "CMD: $CURL --user-agent \"$USER_AGENT\" $CURLARGS \"$SJCARS_NCLIST_URL\""
$CURL  --user-agent "$USER_AGENT" $CURLARGS "$SJCARS_NCLIST_URL" > $NCLIST_HTML_FILENAME
curl_retcode=$?

if [ $curl_retcode -ne 0 ] ; then
    return $curl_retcode
fi

# if the net control list filename exists rename it something else in case
#  there is a problem scraping the web site
if [ -e $NCLIST_FILENAME ] ; then
    mv -f $NCLIST_FILENAME $NCLIST_BACKUP_FILENAME
fi

startcheck=0;
while read line ; do

	# find start of net control list in HTML file
	if [ "$startcheck" -eq 0 ] ; then
		nclist_line=$(echo $line | grep  -i "$SearchStrStart")
		#  Test for a NULL string
		if [ -z "$nclist_line" ] ; then
		    continue;
		else
		    startcheck="1";
		fi
	fi

	# find end of net control list in HTML file
	nclist_end=$(echo $line | grep  -i "You can start editing here")
	# Test if a string is NOT null
	if [ -n "$nclist_end" ] ; then
	    break;
	fi

	# Get netcontrol name & call sign
	ncname=$(echo $line | grep  -i "$SearchStr1" | cut -d ">" -f2 | cut -d "<" -f1)
	if [ -n "$ncname" ] ; then
		read line
		nccall=$(echo $line | grep  -i "$SearchStr1" | cut -d ">" -f2 | cut -d "<" -f1)
		echo "$ncname, $nccall" >> $NCLIST_FILENAME
	fi

done < $NCLIST_HTML_FILENAME
return 0
}

#
# === function getfilelinks() =================
# Set the global vars $preamble_str & $rollcall_str with the links from
# the SJCARS website
#
function getfilelinks ()
{

PREAMBLE_DESIGNATOR="Preamble.pdf"
ROLLCALL_DESIGNATOR="RollCall"

if (( $DEBUG )) ; then
    echo "scrape test getfilelinks"
    echo "URL: $SJCARS_PREAMBLE_URL"
    echo "Designators: $PREAMBLE_DESIGNATOR $ROLLCALL_DESIGNATOR"
    echo
fi

preamble_str="http://sjcars.org/blog/wp-content/uploads/2010/11/Net-Control-Preamble-1.pdf"

#preamble_str=$($CURL --user-agent "$USER_AGENT" $CURLARGS "$SJCARS_PREAMBLE_URL" | grep  -i "$PREAMBLE_DESIGNATOR" | cut -d\" -f2 | cut -d" " -f1)
#curl_retcode=$?
#
#if [ "$DEBUG" -ne 0 ] ; then
#    echo "CURL retcode PREAMBLE link: $curl_retcode"
#fi
#
#if [ $curl_retcode -ne 0 ] ; then
#    return $curl_retcode
#fi

rollcall_str=$($CURL --user-agent "$USER_AGENT" $CURLARGS "$SJCARS_PREAMBLE_URL" | grep  -i "$ROLLCALL_DESIGNATOR" | cut -d\" -f2 | cut -d" " -f1)
curl_retcode=$?

if [ "$DEBUG" -ne 0 ] ; then
    echo "CURL retcode ROLLCALL link: $curl_retcode"
fi

if [ $curl_retcode -ne 0 ] ; then
    return $curl_retcode
fi

return 0

}

# === function find_ncname() =================
# Search config file for net control name
# return line found <first_name lastname>, <email_address>

function find_nc_name()
{
retcode=0
echo "Checking for name: $1"
# Get line number in config file where NET EMAIL LIST begins
list_index=$(grep -n -m 1 "WED_NET_EMAIL_LIST" $email_cfgfile | cut -d':' -f1)
echo "list_index: $list_index"
# Search config file starting from WED_NET_EMAIL_LIST section
nc_email=$(tail -n+$((list_index + 1)) $email_cfgfile | grep -i "$1" )
echo "nc_email: $nc_email"
# Set recode to 1 on error
if [ -z "$nc_email" ] ; then
  retcode=1
fi
return $retcode
}


#
# === Main =================
#

# Clear boolean to determine if net control index should be incremented
BUMPNCINDEX=0

# if there are any args then parse them
if (( $# > 0 )) ; then

    case "$1" in
        test)
	    DEBUG=1
	;;
        next)
	    BUMPNCINDEX=1
	;;
	*)
            echo "Usage: $scriptname <test|next>" >&2
            exit 3
	;;
    esac
fi

# Is curl installed?

type -P curl &>/dev/null
if [ $? -ne 0 ] ; then
  echo "$scriptname: Install cURL please"
  exit 1
fi

# Is mutt installed?

type -P mutt &>/dev/null
if [ $? -ne 0 ] ; then
  echo "$scriptname: Install mutt please"
  exit 1
fi

# Check for necessary files
if (( $DEBUG )) ; then
echo "*** Debug turned on ***"
file_check
fi

# Read configuration file for email lists
SYSOP_EMAIL=$(grep "SYSOP_EMAIL" $email_cfgfile | cut -d"=" -f2)
DEBUG_EMAIL_LIST=$(grep "DEBUG_EMAIL_LIST" $email_cfgfile | cut -d"=" -f2)
SJCARS_EMAIL_LIST=$(grep "SJCARS_EMAIL_LIST" $email_cfgfile | cut -d"=" -f2)

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

if [ -z "$SJCARS_EMAIL_LIST" ] ; then
   echo "Email list has not been configured in $email_cfgfile"
   exit 1
else
   echo "Using SJCARS_EMAIL_LIST: $SJCARS_EMAIL_LIST"
fi

# Scrape NC list from SJCARS website - call internal function
nclist
# If using cURL lib with a C program then do it this way
# $progname > $NCLIST_FILENAME
nclist_retcode=$?

if [ $nclist_retcode -ne 0 ] ; then
  errorhandler "Error scraping SJCARS URL - get net control list"
  exit 1
fi

# make sure the net control name file exists
if [ ! -e "$NCLIST_FILENAME" ] ; then
  errorhandler "file $NCLIST_FILENAME DOES NOT exist"
  exit 1
fi

# if index file doesn't exist create it & set contents to a zero
if [ ! -e "$NCINDEXFILE" ]
then
  echo "INFO: file $NCINDEXFILE DOES NOT exist"
  echo "0" > $NCINDEXFILE
fi

# initialize count of number of lines in Net Control name file
let ncnamefile_linecnt=0

# Loop through the net control file to find what the maximum number of
#+ entries are

while read line ; do
  ncname_line[$ncnamefile_linecnt]=$(echo $line)

#  echo "DEBUG: Line ($ncnamefile_linecnt):  ${ncname_line[$ncnamefile_linecnt]}"

  # Increment the number of lines
  ncnamefile_linecnt=`expr $ncnamefile_linecnt + 1`

done < $NCLIST_FILENAME

# Load the net control index
ncindex=$(cat $NCINDEXFILE)

echo
echo "INFO: Number of names in list $ncnamefile_linecnt, Current Index $ncindex"

# Load the Net control name, callsign & e-mail address

nc_name=$(echo $(echo ${ncname_line[$ncindex]} | awk '{print $1 " " $2}' | cut -f1 -d, ))
nc_callsign=$(echo $(echo ${ncname_line[$ncindex]} | awk '{print $3}' ))

# Search config file for net control name

# oldway: check if an e-mail address was found
# grep -i "$nc_name" "$NCEMAILFILE" > /dev/null
#nc_email=$(echo $(grep -i "$nc_name" "$NCEMAILFILE" | awk '{print $3}' ))

# Returns string <first_name last_name>, <email_address>
find_nc_name "$nc_name"
if [ $? -ne 0 ] ; then
  errorhandler "No e-mail address found for $nc_name"
  exit 1
else
   nc_email=$(echo $nc_email | awk '{print $3}')
fi

echo "INFO: Net Control: $nc_name, Call Sign: $nc_callsign, E-Mail: $nc_email"
echo

# check if the net control index is to be incremented
## This is to allow multiple (2) e-mails in the week preceding the net

if (( "$BUMPNCINDEX" )) ; then
  echo "DEBUG: NC INDEX IS incremented"
  # increment the index for the next net control
  let ncindex=$ncindex+1
  let ncnamefile_linecnt=$ncnamefile_linecnt-1

  # Check if the index needs to wrap
  if [ $ncindex -gt $ncnamefile_linecnt ] ; then
    let ncindex=0
    echo
    echo "DEBUG: Reset ncindex"
    echo
  fi

  # Write new index back out to index file
  echo "$ncindex" > $NCINDEXFILE

else
  echo "DEBUG: NC INDEX is NOT incremented"
fi

# Send an e-mail
## form the message

# get the web links to the NET Preamble & the current call list
getfilelinks
getfilelinks_retcode=$?

if [ $getfilelinks_retcode -ne 0 ] ; then
  errorhandler "Error scraping SJCARS URL - get file links"
  exit 1
fi

# Need to bump the index into list of net control operaters?
if (( "$BUMPNCINDEX" )) ; then
    when=$(echo "TODAY $(date +"%A, %d %B")")
else
# If there are any problems message may not go out when expected
# get day of the week as an integer 0-7
   dow=$(date +%u)
# calculated date should be next wednesday, day 3 of the week
# this assumes current day o week is thurs through sat, dow 4 - 7
#   nextdow=$(($dow - 3))
#   when=$(echo "next $(date -d "next week -$nextdow day" +"%A, %d %B")")
   when=$(echo "next $(date -d "next-wednesday" +"%A, %d %B")")
fi

nc_firstname=$(echo $(echo $nc_name | cut -d' ' -f1 ))
echo "Hello $nc_firstname," > $NCMSGFILE
{
echo
echo "You're up $when, for the 8:00PM SJCARS VHF Net."
echo
echo "You can down load the Roll Call List from this link:"
echo
echo "$rollcall_str"
echo
echo "You can down load the Net Control Preamble from this link:"
echo
echo "$preamble_str"
echo
echo "If you won't be available, please swap with another NCS."
echo
echo "Thanks for being involved,"
echo "/N7JN bot"
} >> $NCMSGFILE

## form the subject
subject=$(echo "You are SJCARS Net Control $when!")

if [ "$DEBUG" -ne 0 ] ; then
    echo "subject: $subject"
    echo "message: "
    cat $NCMSGFILE
fi

send_email

exit 0
