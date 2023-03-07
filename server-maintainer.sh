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
HOSTNAME=$(hostname)
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

eval ${PACKAGE_UPDATE}

additional_packages=("curl" "sshpass" "jq" "sendemail")
for pack_str in ${additional_packages[@]}; do
  if [ ! -e /usr/bin/${pack_str} ]; then
    PACKAGE_INSTALL=${PACKAGE_INSTALL_BASE}${pack_str}
    eval ${PACKAGE_INSTALL}
  fi
done

# check if it's the first week of the month 
WEEK=$(date '+%V')
if [ $[${WEEK}%4] = 0 ]; then
  firstweek=true
else
  firstweek=false
fi
####End of BLOCK1####


####BLOCK2: This block read .env file and use variables in it ####
FILENAME=.env
#ops_abort=0
echo "verify .env file"
if [[ ! -f ${FILENAME} ]]; then
  echo "couldn't find env file in current folder,abort!"
  exit
fi

mapfile -t variables < <(grep -vE '^#|^$' ${FILENAME})
arr_length=${#variables[@]}
if ((arr_length < 3)); then
  echo "bad environment file.Abort"
  exit
fi

#echo "Check if env include key variables"
if [[ ! ${variables[@]} =~ "BK_SERVER1_IP" ]]; then
  echo "missing key variable BK_SERVER1_IP. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "BK_SERVER1_USER" ]]; then
  echo "missing key variable BK_SERVER1_USER. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "BK_SERVER1_PASSWORD" ]]; then
  echo "missing key variable BK_SERVER1_PASSWORD. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "SMTP_SERVER" ]]; then
  echo "missing key variable SMTP_SERVER. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "SMTP_ACCOUNT" ]]; then
  echo "missing key variable SMTP_ACCOUNT. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "SMTP_PASSWORD" ]]; then
  echo "missing key variable SMTP_PASSWORD. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "EMAIL_TO" ]]; then
  echo "missing key variable EMAIL_TO. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "PORTAINER_ADMIN" ]]; then
  echo "missing key variable PORTAINER_ADMIN. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "PORTAINER_PASSWORD" ]]; then
  echo "missing key variable PORTAINER_PASSWORD. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "PORTAINER_PATH" ]]; then
  echo "missing key variable PORTAINER_PATH. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "PORTAINER_URL" ]]; then
  echo "missing key variable PORTAINER_URL. Abort"
  exit
fi
if [[ ! ${variables[@]} =~ "PORTAINER_API_KEY" ]]; then
  echo "missing key variable PORTAINER_API_KEY. Abort"
  exit
fi


printf "total %s variables in env file and they are:\n" $arr_length
echo "${variables[@]}"

echo "use mapfile to define var"
for v in "${variables[@]}"; do 
  eval ${v}
done
####End of BLOCK2####

####BLOCK3: check system status and prepare Email harder
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

#Email notification header

SUBJECT="$DATE Server ${HOSTNAME} maintainer report"
MESSAGE="/tmp/Mail.out"
echo "$ALARMBODY <br />" >> $MESSAGE
echo "" >> $MESSAGE
echo "------------------------------------------------------------------<br /> " >> $MESSAGE

#prepare backup folder in current path
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH
mkdir -p backups/docker_volumes
mkdir -p backups/${HOSTNAME}_${DATE}
mkdir -p backups/monthly

####End of BLOCK3####

####BLOCK4: portainer backup####
echo "Login, lookup and stop stacks"
TOKEN=$(curl -s --connect-timeout 300 -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' --data "{\"username\":\"${PORTAINER_ADMIN}\",\"password\":\"${PORTAINER_PASSWORD}\"}" "${PORTAINER_URL}/api/auth" | jq -r .jwt)
stack_arr=($(curl -s --connect-timeout 300 -X GET "${PORTAINER_URL}/api/stacks" -H "X-API-KEY:${PORTAINER_API_KEY}" | jq '.[]|select(.Status==1)' | jq -r '.Id'))
#echo "stacks is ${stacks}"
#stack_arr=(${stacks})
echo "stack_arr array is ${stack_arr[@]}"
if [[ ! "${stack_arr}" == "" ]]; then
  for s in "${stack_arr[@]}"; do
    curl -s --connect-timeout 300 -X POST "${PORTAINER_URL}/api/stacks/${s}/stop" -H "X-API-KEY:${PORTAINER_API_KEY}"
  done
else
  echo "no runing stacks"
fi
echo "now backup portainer configs which is a tar ball, not include volumes"
curl --connect-timeout 3600 -X POST -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' "${PORTAINER_URL}/api/backup" > backups/${HOSTNAME}_${DATE}/portainer-backup.tar.gz
echo "now backup volumes"
#use rsync to sync volumes into the backup folder and then tarball it as a backup
rsync -avzP --exclude={'backingFsBlockDev','metadata.db','portainer_data/*'} /var/lib/docker/volumes backups/docker_volumes
sleep 1
echo "wail till local rsync operation for tarball"
tar -zc -f backups/${HOSTNAME}_${DATE}/docker_volumes.tgz backups/docker_volumes
echo "now rsync to bk_server1"
if [[ ! ${variables[@]} =~ "BK_SERVER1_SSHPORT" ]]; then
  BK_SERVER1_SSHPORT=22
fi

sshpass -p ${BK_SERVER1_PASSWORD} rsync -avzP backups "-e ssh -p ${BK_SERVER1_SSHPORT} -o StrictHostKeyChecking=no" ${BK_SERVER1_USER}@${BK_SERVER1_IP}:/home/${BK_SERVER1_USER}

#check redumdant backup
echo "monthly backup and clean redumdant files"
if ($firstweek); then
  cp -r ${SCRIPTPATH}/backups/${HOSTNAME}_${DATE} backups/monthly/
fi
find $SCRIPTPATH/backups -maxdepth 1 -type d -mtime +30 -name "${HOSTNAME}*"  -exec rm -rf {} \;
find $SCRIPTPATH/backups/monthly -maxdepth 1 -type d -mtime +180 -name "${HOSTNAME}*" -exec rm -rf {} \;

#check if sync portainer server available
if [[ ! ${variables[@]} =~ "SYNC_SERVER_IP" ]] || [[ ! ${variables[@]} =~ "SYNC_SERVER_USER" ]] || [[ ! ${variables[@]} =~ "SYNC_SERVER_PASSWORD"  ]]; then
  echo "no sync server of portainer available"
else
  echo "sync portainer server now! make sure remote sync server have rsync in sudoer group without the need to input password"
  docker-compose -f "${PORTAINER_PATH}/docker-compose.yml" down
  sshpass -p ${SYNC_SERVER_PASSWORD} rsync -avzP ${PORTAINER_PATH} "-e ssh -p ${SYNC_SERVER_SSHPORT} -o StrictHostKeyChecking=no" --rsync-path="sudo rsync" ${SYNC_SERVER_USER}@${SYNC_SERVER_IP}:/home/${SYNC_SERVER_USER}
  sshpass -p ${SYNC_SERVER_PASSWORD} rsync -avzP /var/lib/docker/volumes "-e ssh -p ${SYNC_SERVER_SSHPORT} -o StrictHostKeyChecking=no" --rsync-path="sudo rsync" ${SYNC_SERVER_USER}@${SYNC_SERVER_IP}:/var/lib/docker/volumes
  docker-compose -f "${PORTAINER_PATH}/docker-compose.yml" up -d
fi


####End of Block4####

####Block5: web content and  database backup (volumes back up have include database backup, just double secure important application####
#backup web content in dnmp/www

#backup docker mysql8
#docker ps | grep 'mysql' &> /dev/null
#if [ $? ]; then
#  docker exec -t mysql bash -c "rm -fr /dump ; mkdir /dump ; mysqldump -h 127.0.0.1 -u root -ppassword eccee > /dump/eccee-${DATE}.sql"
#  docker cp mysql:/dump/. $SCRIPTPATH/backups/$DATE
#  echo "mysql database: eccee have been successfully exported" >> $MESSAGE
#else
#  echo "container mysql in not running,backup fail <br />" >> $MESSAGE
#
#fi



##pack all data to the day's backup package, and delete old backup(7days before)
#tar -zc -f backups/$DATE.tgz backups/$DATE
#if [ -f backups/$DATE.tgz ]; then
#  rm -fr backups/$DATE
#  find $SCRIPTPATH/backups/ -name "*.tgz" -mtime +7 -delete
#fi
#echo "all availabe backup have been packed" >> $MESSAGE


####End of Block5####
#restart stacks
if [[ ! "${stack_arr}" == "" ]]; then
  for s in "${stack_arr[@]}"; do
    curl -s --connect-timeout 300 -X POST "${PORTAINER_URL}/api/stacks/${s}/start" -H "X-API-KEY:${PORTAINER_API_KEY}"
  done
  echo "stacks are all back to work now"
fi

##### call sendemail
sendemail -f ${SMTP_ACCOUNT} -t ${EMAIL_TO} -s ${SMTP_SERVER} -u ${SUBJECT} -o message-content-type=html -o message-charset=utf8 -o message-file=${MESSAGE} -xu ${SMTP_ACCOUNT} -xp ${SMTP_PASSWORD}
rm /tmp/Mail.out

echo "Server Maintainer script have finished its job"
