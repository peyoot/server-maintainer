#!/bin/bash
## To use this script, please put sendemail.sh in /usr/bin
## any issue please report to peyoot#hotmail.com 
## check if bc package have been installed, if not simply sudo apt install bc
## your need to chage necessary parameters in env.example file and save as .env
LOGFILE="/var/log/server_maintainer.log"
MANUALLY_RUN=false
has_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "you need root privilege to run the script" | tee ${LOGFILE}
	exit 1
    fi
}
has_root

####BLOCK1: check the availability of necessary packages and install missing dependencies####
#check os
THIS_HOSTNAME=$(hostname)
OS_RELEASE=$(awk -F= '/^NAME/{gsub(/"/, "", $2);print $2}' /etc/os-release)
if [[ "$OS_RELEASE" =~ "Ubuntu" ]] || [[ "$OS_RELEASE" =~ "Debian" ]]; then
  PACKAGE_UPDATE="apt -qq update"
  PACKAGE_INSTALL_BASE="apt -qq -y install "
elif [[ "$OS_RELEASE" =~ "openEuler" ]] || [[ "$OS_RELEASE" =~ "Centos" ]]; then
  PACKAGE_UPDATE="dnf -q check-update"
  PACKAGE_INSTALL_BASE="dnf -q -y install "
else
  echo "This distribution haven't been test yet" | tee ${LOGFILE}
  exit
fi

if [ -x "$(command -v docker-compose)" ]; then
#  echo "SUCCESS: docker-compose (v1) is installed."
  COMPOSE_COMMAND="docker-compose"
elif $(docker compose &>/dev/null) && [ $? -eq 0 ]; then
#  echo "SUCCESS: docker compose (v2) is installed."
  COMPOSE_COMMAND="docker compose"
else
    echo "ERROR: neither \"docker-compose\" nor \"docker compose\" appear to be installed."
    exit 1
fi


if [ ! -d /etc/server-maintainer ]; then
  eval ${PACKAGE_UPDATE}
fi

additional_packages=("curl" "sshpass" "jq")
for pack_str in ${additional_packages[@]}; do
  if [ ! -e /usr/bin/${pack_str} ]; then
    PACKAGE_INSTALL=${PACKAGE_INSTALL_BASE}${pack_str}
    eval ${PACKAGE_INSTALL}
  fi
done

#install packages like sendemail which couldn't be installed via dnf
if [[ ! -e /usr/local/bin/sendEmail.pl ]]; then
  wget https://raw.githubusercontent.com/zehm/sendEmail/master/sendEmail.pl
  chmod +x sendEmail.pl
  mv sendEmail.pl /usr/local/bin/
  ln -s /usr/local/bin/sendEmail.pl /usr/local/bin/sendemail
fi

# check if it's the first week of the month 
WEEK=$(date '+%V')
if [ $[${WEEK}%4] = 0 ]; then
  firstweek=true
else
  firstweek=false
fi

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
####End of BLOCK1####


####BLOCK2: This block read configuration file and use variables in it ####
FILENAME=/etc/server-maintainer/server-maintainer.conf
#server-maintainer.conf have more priviledge than .env
echo "verify configuration file"

if [[ ! -f ${FILENAME} ]]; then
  echo "Couldn't find the server-maintainer.conf"
  echo "now try .env in script path"
  if [[ ! -f .env ]]; then
    echo "couldn't find env file in current folder as well,abort!" | tee ${LOGFILE}
    exit
  else
    MANUALLY_RUN=true
    FILENAME=.env
  fi
fi

if [[ ! -f ${FILENAME} ]]; then
  echo "No valid configuration file! Abort!"
  exit
fi
mapfile -t variables < <(grep -vE '^#|^$' ${FILENAME})
arr_length=${#variables[@]}
if ((arr_length < 3)); then
  echo "bad environment file.Abort" | tee ${LOGFILE}
  exit
fi

#echo "Check if env include key variables"

if [[ ! ${variables[@]} =~ "BK_PATH" ]]; then
  echo "No local backup path defined. Use default one: /var/local/server-maintainer"
  if (${MANUALLY_RUN}); then
    BK_PATH=$SCRIPTPATH
  else
    BK_PATH=/var/local/server-maintainer
  fi
fi

if [[ ! ${variables[@]} =~ "BK_SERVER1" ]]; then
  echo "missing key variable BK_SERVER1. Abort"
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


#printf "total %s variables in env file and they are:\n" $arr_length
#echo "${variables[@]}"

echo "use mapfile to define var"
for v in "${variables[@]}"; do 
  eval ${v}
done


#prepare sites of dnmp that need backup
site_vars=()
for var in "${variables[@]}"
do
   if [[ $var == SITE* ]]
   then
      # Remove chars before =
      new_var=${var#*=}
      # Add to array
      site_vars+=("$new_var")

   fi
done

site_num=${#site_vars[@]}
#echo "There are ${site_num}  sites to be backup in dnmp."

server_vars=()
for s_var in "${variables[@]}"
do
   if [[ $s_var == BK_SERVER* ]]
   then
      # Remove chars before =
      ns_var=${s_var#*=}
      # Add to array
      server_vars+=("$ns_var")

   fi
done

server_num=${#server_vars[@]}
#echo "There are ${server_num} backup servers."





####End of BLOCK2####

####BLOCK3: check system status and prepare Email harder
DATE=$(date +%Y-%m-%d-%H-%M)
ramusage=$(free | awk '/Mem/{printf("RAM Usage: %.2f\n"), $3/$2*100}'| awk '{print $3}')
diskusage=$(df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB %s\n", $3,$2,$5}' | awk '{print $4}' | awk -F'%' '{print $1}')
cpuusage=$(top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}' | awk '{print $3/4}')
SUBJECT="$DATE Server ${THIS_HOSTNAME} maintainer report"
MESSAGE="/tmp/Mail.out"
echo "<h3>CPU/Memory/Disk Utilization</h3>" >> $MESSAGE
if [ $(echo "$ramusage > 80"|bc) -eq 1 ]; then
  echo "Memory Alarm: reach ${ramusage}% utilization <br />" >> $MESSAGE
fi
if [ $(echo "$diskusage > 90"|bc) -eq 1 ]; then
  echo "Disk Alarm: / reach ${diskusage}% utilization <br />" >> $MESSAGE
fi
if [ $(echo "$cpuusage > 0.7"|bc) -eq 1 ]; then
  echo "CPU Alarm: reach 70% utilization <br />" >> $MESSAGE
fi
echo "Only zero alarm in the above status that can indicate a healthy server system! <br /> " >> $MESSAGE
echo "------------------------------------------------------------------<br /> " >> $MESSAGE
echo "<h3>Backup process log</h3>" >> $MESSAGE

#prepare backup folder in current path
#SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
#cd $SCRIPTPATH


if [[ ! -d "${BK_PATH}" ]]; then
  mkdir -p ${BK_PATH}
fi
if [[ ! -d "${BK_PATH}/backups" ]] && (${MANUALLY_RUN}); then
  install -o ${USER} -g ${USER} -d ${BK_PATH}/backups
fi
if [[ ! -d "${BK_PATH}/backups/monthly" ]] && (${MANUALLY_RUN}); then
  install -o ${USER} -g ${USER} -d ${BK_PATH}/backups/monthly
else
  mkdir -p ${BK_PATH}/backups/monthly
fi
if [[ ! -d "${BK_PATH}/backups/docker_volumes" ]] && (${MANUALLY_RUN}); then
  install -o ${USER} -g ${USER} -d ${BK_PATH}/backups/docker_volumes
else
  mkdir -p ${BK_PATH}/backups/docker_volumes
fi
if (${MANUALLY_RUN}); then
  install -o ${USER} -g ${USER} -d ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}
  install -o ${USER} -g ${USER} -d ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/dnmp_configs
else
  mkdir -p ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/dnmp_configs
fi



####End of BLOCK3####

####BLOCK4: portainer backup####
#get local environment
local_endpoint=$(curl -s --connect-timeout 300 -X GET "${PORTAINER_URL}/api/endpoints" -H "X-API-KEY:${PORTAINER_API_KEY}" |  jq '.[]|select(.Type==1)' | jq -r '.Id')
echo "start backup process, this will take quite a while. please wait..."
echo "Login, lookup and stop stacks and solo containers <br />" >> $MESSAGE
TOKEN=$(curl -s --connect-timeout 300 -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' --data "{\"username\":\"${PORTAINER_ADMIN}\",\"password\":\"${PORTAINER_PASSWORD}\"}" "${PORTAINER_URL}/api/auth" | jq -r .jwt)
stack_arr=($(curl -s --connect-timeout 300 -X GET "${PORTAINER_URL}/api/stacks" -H "X-API-KEY:${PORTAINER_API_KEY}" | jq '.[]|select(.Status==1)' | jq -r '.Id'))
echo "Running stack ID list:  ${stack_arr} <br />" >> $MESSAGE
#echo "stack_arr array is ${stack_arr[@]}"
if [[ ! "${stack_arr}" == "" ]]; then
  for s in "${stack_arr[@]}"; do
    curl -s -o /dev/null --connect-timeout 300 -X POST "${PORTAINER_URL}/api/stacks/${s}/stop" -H "X-API-KEY:${PORTAINER_API_KEY}"
  done
else
  echo "no runing stacks <br />" >> $MESSAGE
fi
sleep 30
#echo "check running solo containers"
running_containers=($(curl -s --connect-timeout 300 -X GET "${PORTAINER_URL}/api/endpoints/${local_endpoint}/docker/containers/json" -H "X-API-KEY:${PORTAINER_API_KEY}" | jq '.[]|select(.Names!=["/portainer"])' | jq -r '.Id'))
echo "Running solo container ID list: ${running_containers} <br />" >> $MESSAGE

if [[ ! "${running_containers}" == "" ]]; then
  for d in "${running_containers[@]}"; do
    curl -s -o /dev/null --connect-timeout 300 -X POST "${PORTAINER_URL}/api/endpoints/${local_endpoint}/docker/containers/${d}/stop" -H "X-API-KEY:${PORTAINER_API_KEY}"
  done
else
  echo "no runing solo containers <br />" >> $MESSAGE
fi
sleep 15

echo "backup portainer configs which is a tar ball, not include volumes <br />"  >> $MESSAGE
echo "now backup portainer"
#curl -s --connect-timeout 3600 -X POST "${PORTAINER_URL}/api/backup" -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' --data "{\"password\":\"${PORTAINER_PASSWORD}\"}" > ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/portainer-backup_${DATE}.tar.gz.encrypted
curl -s --connect-timeout 3600 -X POST "${PORTAINER_URL}/api/backup" -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' --data "{\"password\":\"${PORTAINER_PASSWORD}\"}" > ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/portainer-backup_${DATE}.tar.gz.encrypted
echo "end portainer backup"
echo "backup volumes <br />" >> $MESSAGE
#use rsync to sync volumes into the backup folder and then tarball it as a backup
rsync -az --delete --exclude={'backingFsBlockDev','metadata.db','portainer_data/*'} /var/lib/docker/volumes ${BK_PATH}/backups/docker_volumes
sleep 1
echo "pack tarball for portainer backup data and volumes <br />" >> $MESSAGE
tar -zc -f ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/docker_volumes.tgz -C ${BK_PATH}/backups/ docker_volumes

if [[ ! ${variables[@]} =~ "SYNC_SERVER_SSHPORT" ]]; then
  SYNC_SERVER_SSHPORT=22
fi


#check if sync portainer server available
if [[ ! ${variables[@]} =~ "SYNC_SERVER_IP" ]] || [[ ! ${variables[@]} =~ "SYNC_SERVER_USER" ]] || [[ ! ${variables[@]} =~ "SYNC_SERVER_PASSWORD"  ]]; then
  echo "no sync server of portainer available, backup finished <br />" >> $MESSAGE 
else
  echo "sync portainer server now! <br /> " >> $MESSAGE
  ${COMPOSE_COMMAND} -f "${PORTAINER_PATH}/docker-compose.yml" down
  sshpass -p ${SYNC_SERVER_PASSWORD} ssh -p${SYNC_SERVER_SSHPORT} -o StrictHostKeyChecking=no ${SYNC_SERVER_USER}@${SYNC_SERVER_IP} 'if [ ! -d "/home/${SYNC_SERVER_USER}/docker" ] ; then mkdir -p docker ; else ${COMPOSE_COMMAND} -f "/home/${SNYC_SERVER_USER}/docker/portainer/docker-compose.yml" down ; fi'
  TEMP_SUDO_RSYNC='echo -n "#!" > mypass ; echo "/bin/bash" >> mypass ; echo "echo \"'${SYNC_SERVER_PASSWORD}'\"" >> mypass ; chmod +x mypass ; SUDO_ASKPASS=./mypass sudo -A rsync'
  sshpass -p ${SYNC_SERVER_PASSWORD} rsync -az ${PORTAINER_PATH} "-e ssh -p ${SYNC_SERVER_SSHPORT} -o StrictHostKeyChecking=no" --rsync-path="${TEMP_SUDO_RSYNC}"  ${SYNC_SERVER_USER}@${SYNC_SERVER_IP}:/home/${SYNC_SERVER_USER}/docker
  sshpass -p ${SYNC_SERVER_PASSWORD} rsync -az /var/lib/docker/volumes "-e ssh -p ${SYNC_SERVER_SSHPORT} -o StrictHostKeyChecking=no" --rsync-path="${TEMP_SUDO_RSYNC}"  ${SYNC_SERVER_USER}@${SYNC_SERVER_IP}:/var/lib/docker/
  sshpass -p ${SYNC_SERVER_PASSWORD} ssh -p${SYNC_SERVER_SSHPORT} -o StrictHostKeyChecking=no ${SYNC_SERVER_USER}@${SYNC_SERVER_IP} 'rm -rf mypass ; if [ -f "/home/${SYNC_SERVER_USER}/docker/portainer/docker-compose.yml" ] ; then docker-compose -f  "/home/${SYNC_SERVER_USER}/docker/portainer/docker-compose.yml" up ; fi'
  ${COMPOSE_COMMAND} -f "${PORTAINER_PATH}/docker-compose.yml" up -d
fi

####End of Block4####


##pack all data to the day's backup package, and delete old backup(7days before)
#tar -zc -f backups/$DATE.tgz backups/$DATE
#if [ -f backups/$DATE.tgz ]; then
#  rm -fr backups/$DATE
#  find $SCRIPTPATH/backups/ -name "*.tgz" -mtime +7 -delete
#fi
#echo "all availabe backup have been packed" >> $MESSAGE


#resume stacks
sleep 10
if [[ ! "${stack_arr}" == "" ]]; then
  for s in "${stack_arr[@]}"; do
    curl -s -o /dev/null --connect-timeout 300 -X POST "${PORTAINER_URL}/api/stacks/${s}/start" -H "X-API-KEY:${PORTAINER_API_KEY}"
  done
  echo "stacks are all back to work now <br />"  >> $MESSAGE
fi

sleep 5

if [[ ! "${running_containers}" == "" ]]; then
  for d in "${running_containers[@]}"; do
    curl -s -o /dev/null --connect-timeout 300 -X POST "${PORTAINER_URL}/api/endpoints/${local_endpoint}/docker/containers/${d}/start" -H "X-API-KEY:${PORTAINER_API_KEY}"
  done
  echo "All containers back to work now <br />"  >> $MESSAGE
fi


####Block5: web content and  database backup (volumes back up have include database backup, just double secure important application####
#backup web content in dnmp_www
#check if web container is working
sleep 10
echo "now backup web sites in dnmp"
docker ps |grep nginx &> /dev/null
if [ $? -eq 0 ]; then
  for sites in "${site_vars[@]}"
  do
    IFS=',' read -r site site_db db_host db_user db_password <<< "$sites"


#    echo "site: $site"
#    echo "site_db: $site_db"
#    echo "db_host: $db_host"
#    echo "db_user: $db_user"
#    echo "db_password: $db_password"
    hostdate=${DATE}
    echo "today is ${hostdate}"

    if (${MANUALLY_RUN}); then
      install -o ${USER} -g ${USER} -d ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/${site}
    else
      mkdir -p ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/${site}
    fi

#    docker exec -t -e site=$site -e hostdate=$DATE nginx sh -c "if [ ! -d /dump ] ; then mkdir -p /dump ; fi;  tar -zcf /dump/${site}-${hostdate}.tgz -C /www/ ${site}"
#    docker cp nginx:/dump/${site}-${DATE}.tgz ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/${site}/ 
    if [[ $db_host == mysql* ]]
    then
      docker ps | grep ${db_host} &> /dev/null
      if [ $? -eq 0 ]; then
        docker exec -e site_db=$site_db -e db_user=$db_user -e db_password=$db_password -e hostdate=${DATE} ${db_host} bash -c 'if [ ! -d "/dump" ]; then mkdir /dump; fi;  mysqldump -h 127.0.0.1 -u ${db_user} -p${db_password} ${site_db} > /dump/${site_db}_${hostdate}.sql '
        docker cp  mysql:/dump/${site_db}_${DATE}.sql  ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/${site}/
        echo "mysql database: eccee have been successfully exported" >> $MESSAGE
      else
        echo "container mysql in not running,backup fail <br />" >> $MESSAGE

      fi
    fi
    tar -zcf ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/${site}/${site}_${DATE}.tgz -C ${DNMP_WWW} ${site}
  done
#clearn dump file in container mysql, we only need clean one time because we dump tgz for each site
docker exec mysql bash -c "rm -rf /dump"

#backup nignx config
tar -zcf  ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE}/dnmp_configs/services_${DATE}.tgz -C ${DNMP_SERVICES} .

else
  echo "contianer nginx seems not up yet!"
fi

echo "now prepare bk_server credentials"
for server in "${server_vars[@]}"
do
  IFS=',' read -r bk_server_ip bk_server_port bk_server_user bk_server_password <<< "$server"
#  echo "bk_server_ip: $bk_server_ip"
#  echo "bk_server_port: $bk_server_port"
#  echo "bk_server_user: $bk_server_user"
#  echo "bk_server_password: $bk_server_password"
  echo "now transfer backup tarball to ${bk_server_ip}"
  echo "transfer backup tarball to $bk_server_ip <br />"  >> $MESSAGE

  if [[ "$bk_server_port" == "" ]]; then
    $bk_serve_port=22
  fi


  sshpass -p ${bk_server_password} ssh -p ${bk_server_port} -o StrictHostKeyChecking=no ${bk_server_user}@${bk_server_ip} "mkdir -p remote-bk/${THIS_HOSTNAME}"
  sshpass -p ${bk_server_password} rsync -az ${BK_PATH}/backups "-e ssh -p ${bk_server_port} -o StrictHostKeyChecking=no" ${bk_server_user}@${bk_server_ip}:/home/${bk_server_user}/remote-bk/${THIS_HOSTNAME}/server-maintainer

  sshpass -p ${bk_server_password} ssh -p ${bk_server_port} -o StrictHostKeyChecking=no ${bk_server_user}@${bk_server_ip} "find remote-bk/${THIS_HOSTNAME}/server-maintainer/backups -maxdepth 1 -type d -mtime +32 -name \"${THIS_HOSTNAME}*\" | xargs rm -rf"

done


#check redumdant backup
echo "monthly backup and clean redumdant files <br />" >> $MESSAGE
if ($firstweek); then
  echo "first week flag toggled"
  cp -r ${BK_PATH}/backups/${THIS_HOSTNAME}_${DATE} ${BK_PATH}/backups/monthly/
fi
find ${BK_PATH}/backups -maxdepth 1 -type d -mtime +32 -name "${THIS_HOSTNAME}*" | xargs rm -rf
find ${BK_PATH}/backups/monthly -maxdepth 1 -type d -mtime +180 -name "${THIS_HOSTNAME}*" | xargs rm -rf


####End of Block5####






##### call sendemail
sendemail -f ${SMTP_ACCOUNT} -t ${EMAIL_TO} -s ${SMTP_SERVER} -u ${SUBJECT} -o tls=no -o message-content-type=html -o message-charset=utf8 -o message-file=${MESSAGE} -xu ${SMTP_ACCOUNT} -xp ${SMTP_PASSWORD}
rm /tmp/Mail.out

echo "Server Maintainer script have finished its job on ${DATE}!" | tee ${LOGFILE}

LOGSIZE=`ls -l ${LOGFILE} | awk '{ print $5 }'`

if [ $LOGSIZE -gt 10241024 ]; then
  rm -rf ${LOGFILE}.1
  mv ${LOGFILE} ${LOGFILE}.1
fi
