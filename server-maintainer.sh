#!/bin/bash
## To use this script, please put sendemail.sh in /usr/bin
## any issue please report to peyoot#hotmail.com 
## check if bc package have been installed, if not simply sudo apt install bc
##

DATE=$(date +%Y-%m-%d-%H-%M)
ramusage=$(free | awk '/Mem/{printf("RAM Usage: %.2f\n"), $3/$2*100}'| awk '{print $3}')
diskusage=$(df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB %s\n", $3,$2,$5}' | awk '{print $4}' | awk -F'%' '{print $1}')
cpuusage=$(top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}' | awk '{print $3/4}')
ALARMBODY="CPU/Memory/Disk Utilization"
if [ $(echo "$ramusage > 80"|bc) -eq 1 ]; then
  echo "Memory Alarm: reach ${ramusage}% utilization" >> $ALARMBODY
fi
if [ $(echo "$diskusage > 90"|bc) -eq 1 ]; then
  echo "Disk Alarm: / reach ${diskusage}% utilization" >> $ALARMBODY
fi
if [ $(echo "$cpuusage > 0.7"|bc) -eq 1 ]; then
  echo "CPU Alarm: reach 70% utilization" >> $ALARMBODY
fi
#### database backup####
#echo script log to message for email report
#put database backup here




#####
SUBJECT="$DATE Server $(hostname) maintainer report"
MESSAGE="/tmp/Mail.out"
TO="peyoot@hotmail.com"
echo "$ALARMBODY" >> $MESSAGE
echo "" >> $MESSAGE
echo "------------------------------------------------------------------" >> $MESSAGE

/usr/bin/sendemail.sh "$TO" "$SUBJECT" ""$MESSAGE""
rm /tmp/Mail.out

#######每周备份，内容生成到/var/log/weekly.report中#######
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH
mkdir -p backups/$DATE

#backup code here
#backup docker mysql8


#backup docker mysql5


#backup docker wenkan-db postgresql
docker ps -a | grep 'wekan-db' &> /dev/null
if [ $? = 0 ]; then
  docker exec -t wekan-db bash -c "rm -fr /dump ; mkdir /dump ; mongodump -o /dump/"
  docker cp wekan-db:/dump $SCRIPTPATH/backups/$DATE
  tar -zc -f backups/$DATE.tgz -C $SCRIPTPATH/backups/$DATE wekan
  if [ -f backups/$DATE.tgz ]; then
    rm -fr backups/$DATE
    find $SCRIPTPATH/backups/ -name "*.tgz" -mtime +7 -delete
  fi 
else
  echo "wekan-db container is not running" >> $MESSAGE
fi
