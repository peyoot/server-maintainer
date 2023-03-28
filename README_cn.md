#### server-maintainer简介
这是一个服务器运维和备份的脚本工具，用于服务器的健康状态上报，docker和docker-compose的备份和冗余服务器同步。如果您有一些服务使用docker，并且你需要定期报告服务器运行状态，备份和同步重要的数据，以便在服务器硬件故障或失效时随时切换备用平台，那么server-maintainer是合适的选择。

您可以在一个或多个服务器上运行本项目的脚本。为了实现本脚本的最佳匹配，建议您以下面方式运营您的docker平台：

1. 以docker-compose的方式运行portainer, 路径在~/docker/portainer
2. 用portainer运行docker-compose的相关容器服务（即stack)
3. 所有服务的卷由portainer管理

#### 使用方法
请将env.sample中的参数调整为所需的值，另存为.env  
然后就可以直接运行 sudo ./server-maintainer.sh

也可以将脚本放到cron或是systemctl的定期任务，以便自动备份


#### 服务器健康状态监测
本项目脚本会检测服务器的健康状态：包括硬盘和内存，CPU占用率等数据，并通过电子邮件发送报告。

#### docker服务的备份
本项目脚本的主要功能是备份指定的容器服务和数据，脚本会导出一份portainer的备份，并同时把portainer中的volume（portainer自身除外）也同步到备份服务器上。除了备份到数据服务器外，脚本也能同步整个portainer的volume到另一台热备服务器，以便在本服务器不可用时，可随时启用热备服务器作为替代。

#### 服务器的目录结构
一般地，源服务器上会有server-maintainer的项目目录，同时也有一个docker的目录，而portainer则位于docker目录下。
而目标备份或同步服务器上，可以和上面结构一样，但多了一个remote-bk作为备份路径。
```
源服务器和同步服务器：
~/git/tools/server-maintainer
               |__server-maintainer.sh
			   |__.env
			   |__backups
			        |__monthly
~/docker
  |__ portainer
        |__ docker-compose.yml

备份服务器：
~/remote-bk
    |__hostname/server-maintainer/backups
/var/lib/docker/volumes

注：备份服务器和同步服务器可以是同一个服务器，也可以不同
```


