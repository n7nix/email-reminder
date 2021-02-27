# email-reminder

Scripts that use crontab to email a group of a recurring event.
The scripts are used for either:
*  a weekly net with rotating net control
*  a bi-weekly drill with rotating net control and a general meeting on alternate weeks

These scripts use mutt mail program from a script executed from crontab for emailing weekly reminders.
There is a single config file for both scripts, email addresses are maintained here:

```/etc/emailremind/whiteboxlist.txt```

## What the scripts do

### 1. Two identical email notices for a weekly event: ncnextup_smtp.sh

* Notice email is sent out day of and day after event for a rotating net control

##### Command line arguments

``` ncnextup_smtp.sh <test> <next>```

* `No args` used: Send reminder email to net control
* `next`: Send reminder email and increment index for next net control

* `test` : Set debug flag, does not send to email list

##### crontab example

* Messages are sent on:
  * Wednesday, (day of) to current net control
  * Thursday, (day after) to next net control

```
5    4   *   *   3  /bin/bash /home/gunn/bin/ncnextup_smtp.sh next
5    4   *   *   4  /bin/bash /home/gunn/bin/ncnextup_smtp.sh
```

##### email distribution list
* Notification email is sent to the following:
  * current netcontrol taken from addresses following this variable in the whiteboxlist.txt file:
    * **WED_NET_EMAIL_LIST=**
  * plus all addresses entered after this variable
    * **SJCARS_EMAIL_LIST=**

##### Net Control List
* The list of callsigns used for the net control rotation is taken from this web URL
  * https://sjcars.wordpress.com/nets/
    *  **OLD address** http://sjcars.org/blog/ncs-rotation

### 2. Single email notice on alternate weeks: wbnextup_smtp.sh

* Notice email is sent out day before event (Monday)
* Two different messages are sent depending on week
  * 2nd & 4th Tuesday events are drill days
  * 1st & 3rd Tuesday events are discussion & maintenance days

##### Command line arguments

```wbnextup_smtp.sh <test> <alt>```

* `No args` used: Send reminder email for 2nd & 4th Tuesday drill
* `alt` : Set alternate week flag to send reminder email for 1st & 3rd Tuesday meeting.
* `test` : Set debug flag, does not send to email list

##### crontab example

* `date +\%u -eq 1` Checks date for being a Monday (day before event)

```
31   4  1-6,14-20   *  * [ `date +\%u` -eq 1 ] && /bin/bash /home/gunn/bin/wbnextup_smtp.sh alt
31   4  7-13,21-28  *  * [ `date +\%u` -eq 1 ] && /bin/bash /home/gunn/bin/wbnextup_smtp.sh

```

##### email distribution lists

* Distribution lists are defined in file: _/etc/emailremind/whiteboxlist.txt_
* 2nd & 4th Tuesday drills use addresses entered after these variables:
  *  **GOOGLE_EMAIL_LIST=**
  *  **LOPEZ_EMAIL_LIST=**
* 1st & 3rd Tuesday drills use addresses entered after only one variable:
  *  **LOPEZ_EMAIL_LIST=**
