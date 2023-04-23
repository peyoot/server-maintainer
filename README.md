#### Introduction to server-maintainer
[中文](README_cn.md "中文")  

This is a script tool for server operation and maintenance and backup, which is used for server health reporting, docker and docker-composite backup, and redundant server synchronization. If you have services that use docker and you need to regularly report on server health, back up and synchronize important data so that you can switch standby platforms at any time in case of server hardware failure or failure, then server-maintainer is the right choice.

You can run the project's scripts on one or more servers. To achieve the best match for this script, we recommend that you run your docker platform in the following way:

1. Run portainer as docker-compose, path to ~/docker/portainer
2. Run docker-compose-related container services (i.e. stacks) with portainer
3. All service volumes are managed by Portainer

#### USAGE
You can either run it from script or install it as a systemd daemon.
To run it manually as a tool, you need to have .env config file in the same path of server-maintainer.sh.
run 'sudo ./server-maintainer.sh'

To install it as daemon, just run the install.sh as root. you need to put the configuration in /etc/server-maintainer.conf.
 
just modify the env.sample and rename it to .env if you just need manual tool. For systemd daemon, please copy the modified env.sample to /etc/server-maintainer/server-maintainer.conf after installation.

your can modify server-maintainer.timer to have daemon run on your own schedule. (by default it run on 05:00:00 every day.) 

#### Server health monitoring
This project script will detect the health status of the server: including hard disk and memory, CPU utilization and other data, and send a report by email.

#### Backup of the docker service
The main function of this project script is to back up the specified container service and data, the script will export a copy of Portainer's backup, and synchronize the volume in Portainer (except for Portainer itself) to the backup server. In addition to backing up to a data server, scripts can also synchronize the entire portainer's volume to another hot standby server, so that if this server is unavailable, it can always be enabled as a replacement.


#### Source server directory structure
For manually run, you can git clone this project to any path you like.
The script will have a local backup path BK_PATH, it will transfer or sync backups to remote backup server's remote-bk folder.
here's an example of related folder/files after installation.

```
/usr/local/bin/server-maintainer.sh
/etc/server-maintainer/server-maintainer.conf
/var/local/server-maintainer
		   |__backups
		        |__monthly
~/docker
  |__ portainer
        |__ docker-compose.yml

~/remote-bk
    |__<remote-hostname>/server-maintainer/backups

/var/lib/docker/volumes


```
