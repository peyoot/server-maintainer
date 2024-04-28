#!/bin/bash
#check root
if [[ $EUID -ne 0 ]]; then
  echo "you need root privilege to run the script"
  exit 1
fi

echo 'The script will install the server-maintainer as a tool called by system timer on schedule'
FILENAME=/etc/server-maintainer/server-maintainer.conf
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
  echo "This distribution haven't been test yet"
  exit
fi

if [ ! -d /etc/server-maintainer ]; then
  eval ${PACKAGE_UPDATE}
fi


additional_packages=("curl" "sshpass" "jq" "rsync")
for pack_str in ${additional_packages[@]}; do
  if [ ! -e /usr/bin/${pack_str} ]; then
    PACKAGE_INSTALL=${PACKAGE_INSTALL_BASE}${pack_str}
    eval ${PACKAGE_INSTALL}
  fi
done

#add ts package
if [ ! -e /usr/bin/ts ]; then
   pack_str="moreutils"
   PACKAGE_INSTALL=${PACKAGE_INSTALL_BASE}${pack_str}
   eval ${PACKAGE_INSTALL}
fi

mkdir -p /etc/server-maintainer
cp env.sample /etc/server-maintainer/server-maintainer.sample
cp README.md /etc/server-maintainer/

#SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cp server-maintainer.sh /usr/local/bin && echo 'server-maintainer.sh copied to /usr/local/bin'
chmod +x /usr/local/bin/server-maintainer.sh
cp server-maintainer.service /etc/systemd/system/
cp server-maintainer.timer /etc/systemd/system/
echo 'server-maintainer service and timer installed'
if [[ ! -f ${FILENAME} ]]; then
  echo 'you need define your own configuration file first. Please take /etc/server-maintainer/server-maintainer.sample as reference and rename it server-maintainer.conf'
  echo 'if you prefer to run it manually as a sript tool. you can put the configuration file in the same path of script and change the name as .env'
  echo 'installation finished.'
fi

#rm -rf install.sh
systemctl enable server-maintainer.timer
systemctl start server-maintainer.timer
echo 'The daemon is running now'
