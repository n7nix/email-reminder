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
31   4  1-7,15-21   *  * [ `date +\%u` -eq 1 ] && /bin/bash /home/gunn/bin/wbnextup_smtp.sh alt
31   4  8-14,22-28  *  * [ `date +\%u` -eq 1 ] && /bin/bash /home/gunn/bin/wbnextup_smtp.sh

```
