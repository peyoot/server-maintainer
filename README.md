#### Introduction to server-maintainer
[中文](README_cn.md "中文")  

This is a script tool for server operation and maintenance and backup, which is used for server health reporting, docker and docker-composite backup, and redundant server synchronization. If you have services that use docker and you need to regularly report on server health, back up and synchronize important data so that you can switch standby platforms at any time in case of server hardware failure or failure, then server-maintainer is the right choice.

You can run the project's scripts on one or more servers. To achieve the best match for this script, we recommend that you run your docker platform in the following way:

1. Run portainer as docker-compose, path to ~/docker/portainer
2. Run docker-compose-related container services (i.e. stacks) with portainer
3. All service volumes are managed by Portainer

#### USAGE

change env.sample file name to .env and also change it's content  with your server IP and password, etc
run 'sudo ./server-maintainer.sh'

#### Server health monitoring
This project script will detect the health status of the server: including hard disk and memory, CPU utilization and other data, and send a report by email.

#### Backup of the docker service
The main function of this project script is to back up the specified container service and data, the script will export a copy of Portainer's backup, and synchronize the volume in Portainer (except for Portainer itself) to the backup server. In addition to backing up to a data server, scripts can also synchronize the entire portainer's volume to another hot standby server, so that if this server is unavailable, it can always be enabled as a replacement.


#### Source server directory structure
Generally, there will be a server-maintainer project directory on the source server, as well as a docker directory, and portainer is located in the docker directory.
On the target backup or synchronization server, the structure can be the same as above, but with an additional remote-bk as the backup path.

```
~/git/tools/server-maintainer
               |__server-maintainer.sh
			   |__.env
			   |__backups
			        |__monthly
~/docker
  |__ portainer
        |__ docker-compose.yml

~/remote-bk
    |__<remote-hostname>/server-maintainer/backups

/var/lib/docker/volumes


```
