#### server-maintainer简介
这是一个服务器运维和备份的脚本工具，用于服务器的健康状态上报，docker和docker-compose的备份和冗余服务器同步。如果您有一些服务使用docker，并且你需要定期报告服务器运行状态，备份和同步重要的数据，以便在服务器硬件故障或失效时随时切换备用平台，那么server-maintainer是合适的选择。

您可以在一个或多个服务器上运行本项目的脚本。为了实现本脚本的最佳匹配，建议您以下面方式运营您的docker平台：

1. 以docker-compose的方式运行portainer, 路径在~/docker/portainer
2. 用portainer运行docker-compose的相关容器服务（即stack)
3. 所有服务的卷由portainer管理

#### 使用方法
本项目可以作为工具脚本单独运行，请将env.sample中的参数调整为所需的值，另存为.env文件，请保持.env文件和server-maintainer.sh在同一个目录下。
作为独立工具时，请直接运行 sudo ./server-maintainer.sh

您也可以安装server-maintainer作为系统服务，定期运行，报告服务器状态并备份相关容器和服务。
要把server-maintainer安装为系统服务，请：
1. 运行install.sh安装
2. 将/etc/server-maintainer.conf内容调整为相应的值，包括本地备份路径和远程备份或同步服务器的IP, 通知邮箱信息等。
3. 修改/etc/systemd/system/server-maintainer.timer中的计划运行时间，默认是每天05:00:00运行一次。

#### 服务器健康状态监测
本项目脚本会检测服务器的健康状态：包括硬盘和内存，CPU占用率等数据，并通过电子邮件发送报告。

#### docker服务的备份
本项目脚本的主要功能是备份指定的容器服务和数据，脚本会导出一份portainer的备份，并同时把portainer中的volume（portainer自身除外）也同步到备份服务器上。除了备份到数据服务器外，脚本也能同步整个portainer的volume到另一台热备服务器，以便在本服务器不可用时，可随时启用热备服务器作为替代。

#### 服务器的目录结构
一般地，源服务器上会有需要备份的docker内容，比如~/docker/portainer, docker卷等。这些待定期备份的目标文件。
作为工具手动运行时，只需把配置文件和server-maintainer.sh放在同一个文件夹即可。
如果安装server-maintainer为服务,则server-maintainer.sh被安装到/usr/local/bin下，而配置文件则位于/etc/server-maintainer下。
而目标备份或同步服务器上，用~/remote-bk作为备份路径。
```
独立工具使用时的目录结构：
~/git/tools/server-maintainer
               |__server-maintainer.sh
			   |__.env
安装为系统服务时的安装目录：
/usr/local/bin/server-maintainer.sh
/etc/server-maintainer/server-maintainer.conf
```
备份路径（默认值，可自行在配置文件中修改）
```
本地：/var/local/server-maintainer/
远程：~/remote-bk
注：备份服务器和同步服务器可以是同一个服务器，也可以不同
```


