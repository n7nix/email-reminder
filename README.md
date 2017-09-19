# email-reminder
Scripts that use crontab to email a group of recurring event.
The scripts are used for either:
  *  a weekly net with rotating net control
  *  a bi-weekly drill with a general meeting on alternate weeks

* Uses mutt & crontab to email weekly reminders
* email addresses are maintained in `/etc/emailremind/whiteboxlist.txt`

### two notices for a weekly event
* Notice is sent out day after and day before event for a rotating net control

###### script name: ncnextup_smtp.sh

###### Command line arguments

* test -
* next -

###### crontab

```
5    4   *   *   3  /bin/bash /home/gunn/bin/ncnextup_smtp.sh next
5    4   *   *   4  /bin/bash /home/gunn/bin/ncnextup_smtp.sh
```

### notice for 1st & 3rd Tue, different notice for 2nd & 4th Tue.

* 2nd & 4th Tuesdays are drill days
* 1st & 3rd Tuesdays are discussion & maintenance days
* Two different messages are senting depending on day.

###### script name: wbnextup_smtp.sh
###### Command line arguments
* Any command line argument selects the odd Tuesday message

###### crontab
```
31   4  1-7,15-21   *  * [ `date +\%u` -eq 1 ] && /bin/bash /home/gunn/bin/wbnextup_smtp.sh -
31   4  8-14,22-28  *  * [ `date +\%u` -eq 1 ] && /bin/bash /home/gunn/bin/wbnextup_smtp.sh

```
