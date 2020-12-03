#!/bin/bash
#script name : sendemail.sh
#usage: sendemail.sh receiver@email.com "subject" "body"
account='noreply@eccee.com'
password='kissme123'
smtpserver='smtp.ym.163.com'
to=$1
subject=$2
content=$3
sendemail -f $account -t $to -s $smtpserver -u $subject -o message-content-type=html -o message-charset=utf8 -o message-file=$content -xu $account -xp $password

