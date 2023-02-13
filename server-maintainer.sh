#!/bin/bash
## To use this script, please put sendemail.sh in /usr/bin
## any issue please report to peyoot#hotmail.com 
## check if bc package have been installed, if not simply sudo apt install bc
## your need to chage necessary parameters in env.example file and save as .env

has_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "you need root privilege to run the script" 1>&2
		exit 1
    fi
}
has_root

####BLOCK1: check the availability of necessary packages and install missing dependencies####
#check os
OS_RELEASE=$(awk -F= '/^NAME/{gsub(/"/, "", $2);print $2}' /etc/os-release)
if [[ "$OS_RELEASE" =~ "Ubuntu" ]] || [[ "OS_REALSE" =~ "Debian" ]]; then
  PACKAGE_UPDATE="sudo apt update"
  PACKAGE_INSTALL_BASE="sudo apt install -y "
elif [[ "OS_RELEASE" =~ "openEuler" ]] || [[ "OS_RELEASE" =~ "openEuler" ]]; then
  PACKAGE_UPDATE="sudo dnf check-update"
  PACKAGE_INSTALL_BASE="sudo dnf install -y "
else
  echo "This distribution haven't been test yet"
  exit
fi

 
if [ ! -e /usr/bin/sshpass ]; then
  PACKAGE_INSTALL=${PACKAGE_INSTALL_BASE}."sshpass"
  eval ${PACKAGE_UPDATE}
  eval ${PACKAGE_INSTALL}
fi



#check jq
if [ ! -e /usr/bin/sendemail ]; then
  sudo apt update
  sudo apt install jq -y
fi

####End of BLOCK1####


####BLOCK2: This block read .env file and use variables in it ####
FILENAME=.env
#ops_abort=0
echo "verify .env file"
test -e ${FILENAME} || exit
mapfile -t variables < <(grep -vE '^#|^$' ${FILENAME})
arr_length=${#variables[@]}
if ((arr_length < 3)); then
  echo "bad environment file.Abort"
  exit
fi

#echo "Check if env include key variables"
if [[ ! ${variables[@]} =~ "BK_SERVER1_IP" ]]; then
  echo "missing key variables. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "BK_SERVER1_USRNAME" ]]; then
  echo "missing key variables. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "BK_SERVER1_PASSWORD" ]]; then
  echo "missing key variables. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "SMTP_SERVER" ]]; then
  echo "missing key variables. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "SMTP_ACCOUNT" ]]; then
  echo "missing key variables. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "SMTP_PASSWORD" ]]; then
  echo "missing key variables. Abort"
  exit
fi

printf "total %s variables in env file and they are:\n" $arr_length
echo "${variables[@]}"

echo "use mapfile to define var"
for v in "${variables[@]}"; do 
  eval ${v}
done
####End of BLOCK2####


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
