#简介
FAIRINOSimMachine文件为docker镜像SimMachine
fr_docker.tar.gz 为docker工具安装包。

使用方法根据官网用户手册进行使用。


--------------初次使用忽略以下内容--------------
#软件包升级
若之前已使用镜像创建好容器，可选择直接使用软件升级包更新。
下载地址：请至官网下载，FAIRINO SimMachine Software-vX.X.X.zip
#使用步骤
1. 将压缩包解压，得到软件升级包放至虚拟机文件系统，
2. 打开web页面登录-辅助应用-工具应用-系统升级-上传升级包-选择升级包开始升级
3. 等待升级成功提示，重启docker容器。
重启命令：docker restart [容器ID]    /* 容器ID 使用 (docker ps -a) 获取 */
