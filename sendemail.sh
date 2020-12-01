#!/bin/bash
#script name : sendemail.sh
#usage: sendemail.sh receiver@email.com "subject" "body"
account='noreply@company.com'
password='your password'
smtpserver='smtp.company.com'
to=$1
subject=$2
content=$3
sendemail -f $account -t $to -s $smtpserver -u $subject -o message-content-type=html -o message-charset=utf8 -xu $account -xp $password -m $content
