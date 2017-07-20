# kubernetes-
该脚本的作用是一键安装一个master和两个node的k8s集群。

系统环境为 ubuntu 16.04 或者centos 7 docker 14.06 kubernetes 1.6.4 etcd 3.2.1 flannel 0.71 master上集成了UI

注意事项: 本k8s集群是有三台物理机构成，请先确保你有3台机器执行该操作,如果想要增加集群NODES的数量，请在参数NODE_IPS、ETCD_ENDPOINTS、ETCD_NODES中添加。 当选择安装内容的时候，首先分别在三台机器上执行ETCD的安装。均完成后再在master上执行安装Master，node上执行安装Node。 以上操作都没出现错误后，在master上执行add-nodes。 最后是选择是根据需要选择是否安装Harbor、Traefik。
