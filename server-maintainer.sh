#!/bin/bash
## To use this script, please put sendemail.sh in /usr/bin
## any issue please report to peyoot#hotmail.com 
## check if bc package have been installed, if not simply sudo apt install bc
##

DATE=$(date +%Y-%m-%d-%H-%M)
ramusage=$(free | awk '/Mem/{printf("RAM Usage: %.2f\n"), $3/$2*100}'| awk '{print $3}')
diskusage=$(df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB %s\n", $3,$2,$5}' | awk '{print $4}' | awk -F'%' '{print $1}')
cpuusage=$(top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}' | awk '{print $3/4}')
ALARMBODY="<h3>CPU/Memory/Disk Utilization</h3>"
if [ $(echo "$ramusage > 80"|bc) -eq 1 ]; then
  echo "Memory Alarm: reach ${ramusage}% utilization <br />" >> $ALARMBODY
fi
if [ $(echo "$diskusage > 90"|bc) -eq 1 ]; then
  echo "Disk Alarm: / reach ${diskusage}% utilization <br />" >> $ALARMBODY
fi
if [ $(echo "$cpuusage > 0.7"|bc) -eq 1 ]; then
  echo "CPU Alarm: reach 70% utilization <br />" >> $ALARMBODY
fi

####Email notification header

SUBJECT="$DATE Server $(hostname) maintainer report"
MESSAGE="/tmp/Mail.out"
TO="peyoot@hotmail.com"
echo "$ALARMBODY <br />" >> $MESSAGE
echo "" >> $MESSAGE
echo "------------------------------------------------------------------<br /> " >> $MESSAGE


#### database backup####
#echo script log to message for email report
#put database backup here
#######每周备份，内容生成到/var/log/weekly.report中#######



SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH
mkdir -p backups/$DATE

#backup code here
#backup docker mysql8
docker ps | grep 'mysql' &> /dev/null
if [ $? ]; then
  docker exec -t mysql bash -c "rm -fr /dump ; mkdir /dump ; mysqldump -h 127.0.0.1 -u root -ppassword eccee > /dump/eccee-${DATE}.sql"
  docker cp mysql:/dump/. $SCRIPTPATH/backups/$DATE
  echo "mysql database: eccee have been successfully exported" >> $MESSAGE
else
  echo "container mysql in not running,backup fail <br />" >> $MESSAGE

fi


#backup docker mysql5
docker ps | grep 'mysql5' &> /dev/null
if [ $? ]; then
  docker exec -t mysql5 bash -c "rm -fr /dump ; mkdir /dump ; mysqldump -h 127.0.0.1 -u root -ppassword eccee_doc > /dump/ecceedoc-${DATE}.sql"
  docker cp mysql5:/dump/. $SCRIPTPATH/backups/$DATE 
  echo "mysql5 database: ecceedoc have been successfully exported" >> $MESSAGE
else
  echo "container mysql5 in not running,backup fail <br />" >> $MESSAGE

fi

#backup docker wenkan-db postgresql
docker ps | grep 'wekan-db' &> /dev/null
if [ $? = 0 ]; then
  docker exec -t wekan-db bash -c "rm -fr /dump ; mkdir /dump ; mongodump -o /dump/"
#  docker cp wekan-db:/dump $SCRIPTPATH/backups/$DATE
  cp -r /home/robin/docker/wekan/wekan-db-dump/. $SCRIPTPATH/backups/$DATE
  echo "wekan-db is backuped <br />" >> $MESSAGE
else
  echo "wekan-db container is not running, backup fail <br />" >> $MESSAGE
fi

#pack all data to the day's backup package, and delete old backup(7days before)
tar -zc -f backups/$DATE.tgz backups/$DATE
if [ -f backups/$DATE.tgz ]; then
  rm -fr backups/$DATE
  find $SCRIPTPATH/backups/ -name "*.tgz" -mtime +7 -delete
fi
echo "all availabe backup have been packed" >> $MESSAGE



##### call sendemail

/usr/local/bin/sendemail.sh "$TO" "$SUBJECT" "$MESSAGE"
rm /tmp/Mail.out
