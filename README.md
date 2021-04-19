# This is a shell script that I use to monitor CPU/Memory/Disk Usage and backup docker databases weekly ######  
# I want my server to be light and focus on web/app , so no need to use heavy tools on it. ######  
# server maintainer will use sendemail and 3rd party SMTP to send alarm email ##########  
# The script is suitable for you  if you use cloud vps or personal server like me . #####  
# You may need to change some parameters to cater for your hardware conditions/personal account ####  
# Before use this tool ,please install sendemail package first #
```
sudo apt install sendemail
```


Please put sendemail.sh into excutable search PATH, for example /usb/local/bin
```
chmod a+x sendemail.sh
```
You can put the scripts in some places like : /root/tools/ 

mysql and mongodb use docker container

change your database name as you wish, change password according to your server configuration.

you can manually run it. or you can put it into crontab.


enjoy it and good luck!

