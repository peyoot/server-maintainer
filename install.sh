#!/bin/bash
echo 'The script will install the server-maintainer as a tool called by system timer on schedule'
FILENAME=/etc/server-maintainer/server-maintainer.conf
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
  echo 'you need define your own configuration file first. Please take /etc/server-maintainer/server-maintainer.sample as reference and rename it here: /etc/server-maintainer.conf'
  echo 'if you prefer to run it manually as a sript tool. you can put the configuration file in the same path of script and change the name as .env'
  echo 'installation finished.'
fi

#rm -rf install.sh
systemctl enable server-maintainer.timer
systemctl start server-maintainer.timer
echo 'The daemon is running now'
