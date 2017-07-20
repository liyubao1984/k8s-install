#/bin/bash
# 集群组件和版本

#Kubernetes 1.6.4
#Docker  17.04.0-ce
#Etcd 3.2.1
#Flanneld 0.7.1 vxlan 网络
#TLS 认证通信 (所有组件，如 etcd、kubernetes master 和 node)
#RBAC 授权
#kubelet TLS BootStrapping
#kubedns、dashboard、heapster (influxdb、grafana) 插件
#harbor

# 注意事项:

#本k8s集群是有三台物理机构成，请先确保你有3台机器执行该操作,如果想要增加集群NODES的数量，请在参数NODE_IPS、ETCD_ENDPOINTS、ETCD_NODES中添加。
#当选择安装内容的时候，首先分别在三台机器上执行ETCD的安装。均完成后再在master上执行安装Master，node上执行安装node。
#以上操作都没出现错误后，在master上执行add-nodes,方可将节点加入集群
#最后是选择是根据需要选择是否安装Harbor。

# 变量说明：
#1、使用命令head -c 16 /dev/urandom | od -An -t x | tr -d ' '生成BOOTSTRAP_TOKEN的值并替换ecf11198cb68fde328065f54563ca00b
#2、根据自己实际情况设置SERVICE_CIDR、CLUSTER_CIDR的地址。
#3、根据自己实际情况设置ETCD_ENDPOINTS、ETCD_NODES中ETCD集群的IP
#4、根据自己实际情况设置CLUSTER_KUBERNETES_SVC_IP、CLUSTER_DNS_SVC_IP、CLUSTER_DNS_DOMAIN的值
#5、请务必先做好etcd集群后再继续部署其它服务。

# 开始进行集群的安装
echo "欢迎访问https://github.com/liyubao1984/k8s-install 指出错误和提出宝贵意见。"
sleep 5
echo "3秒后开始安装......"
sleep 3
#判断当前用户是否为root用户
    user=`whoami`
    machinename=`uname -m`

    if [ "$user" != "root" ]; then
        echo "请在root下执行该脚本"
        exit 1
    fi

    if [ -f /etc/debian_version ];then
    cat > /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/ubuntu/ xenial main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse
EOF
             
      apt-get -y update
      apt-get install unzip -y
      apt-get remove -y docker docker.io docker-ce docker-engine
      else  
              wget http://mirrors.163.com/.help/CentOS7-Base-163.repo
              yum clean all
              yum -y update
              yum -y install unzip
              systemctl stop firewalld
              systemctl disable firewalld
              yum -y remove docker docker.io docker-ce docker-engine
         fi
         
##翻了个小墙

cd /root 
if [ ! -f hosts ];then 
wget https://iiio.io/download/20170709/Android%E5%AE%89%E5%8D%93%E8%B7%9FLinux%E7%B3%BB%E5%88%97.zip -O hosts.zip
unzip -Plaod.org hosts.zip
cat hosts >> /etc/hosts
fi

##添加nodes
ADD_NODES()
{
for i in $(kubectl get csr |grep -v Approved|awk '{print $1}' |grep csr); do kubectl certificate approve $i ; done
kubectl get nodes
}

##清理集群
Clean_all()
{
#关闭服务,删除文件

systemctl stop kubelet kube-proxy flanneld etcd kube-apiserver kube-controller-manager kube-scheduler

rm -rf /var/lib/{kubelet,etcd,flanneld,docker}

rm -rf /etc/{etcd,flanneld,kubernetes}

systemctl stop docker

systemctl disable kube-apiserver kube-controller-manager kube-scheduler kubelet docker flanneld etcd

rm -rf /etc/systemd/system/{kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,docker,flanneld,etcd}.service

rm -rf /var/run/{flannel,kubernetes,docker}

#清理 kube-proxy 和 docker 创建的 iptables：

iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat

#删除 flanneld 和 docker 创建的网桥：

ip link del flannel.1
ip link del docker0

}

##集群的安装

#获取MASTER_IP  NODE1_IP NODE2_IP 及 Hostnamei
#Get_Node()
#{

#判断IP地址是否合法

echo -n "请分别输入1个MAsterIP和2个NodeIP，用空格分隔:  "
read nodeips

for nodeip in $nodeips
do
       if

           echo $nodeip |egrep -q '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' ; then
                a=`echo $nodeip | awk -F. '{print $1}'`
                b=`echo $nodeip | awk -F. '{print $2}'`
                c=`echo $nodeip | awk -F. '{print $3}'`
                d=`echo $nodeip | awk -F. '{print $4}'`

                for n in  $a $b $c $d ; do
                     if [ $n -ge 255 ] || [ $n -lt 0 ] ; then
                         echo -e " $nodeip 是错误的IP地址! 请重新输入"
                         exit
                  fi
                done
        fi
done

MASTER_IP=$(echo $nodeips|awk -F " " '{print $1}')
NODE1_IP=$(echo $nodeips|awk -F " " '{print $2}')
NODE2_IP=$(echo $nodeips|awk -F " " '{print $3}')

echo -n "请分别输入"$nodex"个NODE的hostname，用空格分隔:  "
read hostnames
m_hostname=$(echo  $hostnames|awk -F " " '{print $1}')
n1_hostname=$(echo $hostnames|awk -F " " '{print $2}')
n2_hostname=$(echo $hostnames|awk -F " " '{print $3}')

echo "Master_IP:  "$MASTER_IP "hostname: "$m_hostname 
echo "NODE1_IP:  "$NODE1_IP "hostname: "$n1_hostname 
echo "NODE2_IP:  "$NODE2_IP "hostname: "$n2_hostname

read -p "请核对信息是否正确，如正确请按任意键继续，如有错误请退出并重新执行该脚本"

echo -n "请输入该节点是MASTER、NODE1、NODE2 ?     MASTER 请输入0，   NODE1请输入1，   NODE2请输入2   并按确认键确认"
read nodenumber
    if [ "$nodenumber" == "0" ]; then
        NODE_IP=$MASTER_IP
        NODE_NAME=$m_hostname
    else
    if [ "$nodenumber" == "1" ]; then
        NODE_IP=$NODE1_IP
        NODE_NAME=$n1_hostname
    elif [ "$nodenumber" == "2" ]; then
        NODE_IP=$NODE2_IP
        NODE_NAME=$n2_hostname

    fi
fi

#通过用户输入的数量来完成配置（未完成）
#}
#echo -n "请输入NODE的数量，为保证ETCD集群的高可用性，建议您输入大于3的基数 ：  "
#read nodex
#if [ "$nodex" -gt 0 ] || [ $nodex -lt 0 ]2>/dev/null ;then
#Get_Node
#else
#echo -e "请重新输入整数"
#exit
#fi
NODE_IPS="$MASTER_IP $NODE1_IP $NODE2_IP" 
#TLS Bootstrapping 使用的 Token，可以使用命令 head -c 16 /dev/urandom | od -An -t x | tr -d ' ' 生成
BOOTSTRAP_TOKEN="ecf11198cb68fde328065f54563ca00b"
#建议用 未用的网段 来定义服务网段和 Pod 网段,以防止和实际使用的网段冲突。
#服务网段 (Service CIDR），部署前路由不可达，部署后集群内使用 IP:Port 可达
SERVICE_CIDR="10.254.0.0/16"
#POD 网段 (Cluster CIDR），部署前路由不可达，**部署后**路由可达 (flanneld 保证)
CLUSTER_CIDR="172.30.0.0/16"
#服务端口范围 (NodePort Range)
NODE_PORT_RANGE="8400-9000"
#etcd 集群服务地址列表
ETCD_ENDPOINTS="https://$MASTER_IP:2379,https://$NODE1_IP:2379,https://$NODE2_IP:2379"
ETCD_NODES=$m_hostname=https://$MASTER_IP:2380,$n1_hostname=https://$NODE1_IP:2380,$n2_hostname=https://$NODE2_IP:2380
#flanneld 网络配置前缀
FLANNEL_ETCD_PREFIX="/kubernetes/network"
#kubernetes 服务 IP (预分配，一般是 SERVICE_CIDR 中第一个IP)
CLUSTER_KUBERNETES_SVC_IP="10.254.0.1"
#集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配)
CLUSTER_DNS_SVC_IP="10.254.0.2"
#集群 DNS 域名
CLUSTER_DNS_DOMAIN="cluster.local."
#将ens160换成内网适配器的名字
#NODE_IP=`ifconfig ens160|grep "inet addr:"|cut -d: -f2|awk '{print $1}'`

#设置Kube-apiserver
KUBE_APISERVER="https://${MASTER_IP}:6443"


# 创建需要使用到的目录

    if [ ! -d /home/k8s/ssl ]; then
        mkdir -p /home/k8s/ssl
    fi
    
    if [ ! -d /etc/etcd/ssl ]; then
        mkdir -p /etc/etcd/ssl
    fi
    
    if [ ! -d /etc/kubernetes/ssl ]; then
        mkdir -p /etc/kubernetes/ssl
    fi
    
    if [ ! -d /etc/flanneld/ssl ]; then
        mkdir -p /etc/flanneld/ssl
    fi
    
# 下载证书生成工具
    if [ ! -f  /usr/bin/cfssl ]; then
        cd /home/k8s/ssl
        rm -f ./*
        wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
        chmod +x cfssl_linux-amd64
        cp cfssl_linux-amd64  /usr/bin/cfssl
    fi
    
    if [ ! -f /usr/bin/cfssljson ]; then
        cd /home/k8s/ssl
        wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
        chmod +x cfssljson_linux-amd64
        cp cfssljson_linux-amd64  /usr/bin/cfssljson
    fi
    
    if [ ! -f  /usr/bin/cfssl-certinfo ]; then
        cd /home/k8s/ssl
        wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
        chmod +x cfssl-certinfo_linux-amd64
        cp cfssl-certinfo_linux-amd64  /usr/bin/cfssl-certinfo
    fi

# 创建 CA 证书和秘钥
CREATE_CA()
{
#创建 CA 证书和秘钥,该操作只在master上操作一次。然后将生成的CA证书复制到每个cluster的/etc/kubernetes/ssl目录下 
echo -e "\n创建 CA 证书和秘钥,该操作只在master上操作一次。然后将生成的ca-key.pem、ca.pem、ca-config.json复制到每个cluster的/etc/kubernetes/ssl目录下，Create CA ......"
sleep 3

cd /home/k8s/ssl

cat > ca-config.json <<EOF	
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "8760h"
      }
    }
  }
}
EOF
cat > ca-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
# 生成CA证书
#请根据自己的实际情况生成CA证书，并且将CA证书分发到每台k8s机器的/etc/kubernetes/ssl，这里为了方便初学者熟悉部署，此处使用一个已经生成的CA证书文件
#如要自己生成可使用命令:cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cat > ca.pem <<EOF
-----BEGIN CERTIFICATE-----
MIIDvjCCAqagAwIBAgIULAEUqD5q54wB6qsh2g3cVJIgrVowDQYJKoZIhvcNAQEL
BQAwZTELMAkGA1UEBhMCQ04xEDAOBgNVBAgTB0JlaUppbmcxEDAOBgNVBAcTB0Jl
aUppbmcxDDAKBgNVBAoTA2s4czEPMA0GA1UECxMGU3lzdGVtMRMwEQYDVQQDEwpr
dWJlcm5ldGVzMB4XDTE3MDcwNjA2MjQwMFoXDTIyMDcwNTA2MjQwMFowZTELMAkG
A1UEBhMCQ04xEDAOBgNVBAgTB0JlaUppbmcxEDAOBgNVBAcTB0JlaUppbmcxDDAK
BgNVBAoTA2s4czEPMA0GA1UECxMGU3lzdGVtMRMwEQYDVQQDEwprdWJlcm5ldGVz
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvN0MN3NLXFOOi0amBWAy
K6Yks2RUiguaOwp3zgLtaN764Hv38TNL2KReyYjrJmdgKPpDoply7XBCZ1VgDrzg
F+Fwhu9FaVSarNev6EHYV2EykWaUP6HeZm4yseqn93NkfOBnzY8f+D3IPYW0dEYw
66gtF6jdphKco0oFW7i92+h2SVekLVvwS0RQ+7En7fsTxHxb+B/inBDUvrrZPRRy
G30vI8jEojuTbWh1WI5cukNRTudbtYBDeq7D2vyvcmte9/6w6Vkwf92cobGTAbO8
IawMleHfzAD5spO6ofIPEuCZW/eridBsMv8OojnEXxObMskkoSICRyfR4VvPFiVZ
UQIDAQABo2YwZDAOBgNVHQ8BAf8EBAMCAQYwEgYDVR0TAQH/BAgwBgEB/wIBAjAd
BgNVHQ4EFgQUlZe3AI3bd+Sk4ZO08Sw5roIPChUwHwYDVR0jBBgwFoAUlZe3AI3b
d+Sk4ZO08Sw5roIPChUwDQYJKoZIhvcNAQELBQADggEBALJLgefeYGGhXlbzuhZK
Vldpe4gvax/+TQJ/F5Uo+3N1IAqnqT7Ez4DwKMSDlu5OnP9p67dGII+atYFf7gfQ
XooTb50pjZQp2wcHwt/anepVhjgxtLem9O/2IkAh5Jgw9vOwELDuY/JzlXw9n6bG
fzhSdd426TyOqqEQwAQ9RpK0/LdABJE5FTGVnpMofLJls0yJKnANxIH227/LdLtq
x7ezNVcPBfkWJ3zeugHSCIvEyu0loNrCNtY3BUrHDzVkJrGWetb6MP120IVDmR6l
jX4iPQS+dNkAy9iUbdLTPIimdjSIy2fves4580ftyW5CsgxKFtH5bdW5XcAYSiri
pHE=
-----END CERTIFICATE-----
EOF
cat > ca-key.pem <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAvN0MN3NLXFOOi0amBWAyK6Yks2RUiguaOwp3zgLtaN764Hv3
8TNL2KReyYjrJmdgKPpDoply7XBCZ1VgDrzgF+Fwhu9FaVSarNev6EHYV2EykWaU
P6HeZm4yseqn93NkfOBnzY8f+D3IPYW0dEYw66gtF6jdphKco0oFW7i92+h2SVek
LVvwS0RQ+7En7fsTxHxb+B/inBDUvrrZPRRyG30vI8jEojuTbWh1WI5cukNRTudb
tYBDeq7D2vyvcmte9/6w6Vkwf92cobGTAbO8IawMleHfzAD5spO6ofIPEuCZW/er
idBsMv8OojnEXxObMskkoSICRyfR4VvPFiVZUQIDAQABAoIBAD4HC0Aa6aFFAAfW
CCiz00ZqppsUVH+SF/FUGszaQUa0FQktLd1Vz48zTL477Z8LTJWovBXm98vrlqOB
cq7kcWTmcaKfatiRJMuneup41ai9D3KZkg7kBrr1bkjonIm0qEgrG2xzmThaci1i
gEW/18lNzqF6oHEuo6stYF0ja5eRTFlMwptHdXiRkwwlwgReWgWcWU4D3zkrMuEZ
0nLl6t2iIMHrXbAqPi5hFG5ugh/vzaMiGi7ZAPo6tAChyDIX4TsjM1+pLHAk8rWy
+0yw+4kO1PbVD+34SaRB4wwXskhvM5CeyaRJ0IgrTaBXsB4zzbS/tE2pXIU9B8f6
In1SlNECgYEA8Uzgqi5wm57qov/rFvwWiUsnLz9iN2Fhs2XUqfW407WlvQH9rqba
wXjdTIyTY+8JOL1WKtxDDaomG0LtdqkzbOucYKhK/4TSDPzVnF1Iy0xeJb1hcx+f
539UOWWaChoaqO4AfJo4D7jcUH0FCrogmuLzmckPXyr1QrAh85jRsD8CgYEAyF5o
d6PugmRttpL08v67ydgS0hxxlP/aU94+NBNCVeYvw4gsPP+1VSi975Hzo4K/YcBW
FlaPkHQluVkk9CMWILsfA0qoto4VFvZ6O6Et5kt/4PlmObt1Mym9HE5XkCBipoxK
UTNlTcC9GgQ4ksDUOK5xkz+fk0jN4QJLYhXKkm8CgYB2boseO+jdGKSFGCKkh1nw
TMiQsgVctRkk2egE+yuaDV+pYt7F5/MaXl4PgjedJudZx+QQ6Uan4EkPvEucn/Mz
lHiOIEufGeuWoEmfk1F1JqhW0ZqQzIbJMn9+JFX0e1d2bkoi3faCEPNhNdtRpoT2
QEnbwwkeZpE2CAjB7NGONQKBgCnYharO4sX6oWsq39tL1f4+kReudw4uLPOtC4Km
rwjvjPQiIVMP+FfzrU82RRLWAJAysgfyRgNeLm66LlyKY1msmrp+QiP2InNsQHTp
oYNiKy/aBj5yZvSrd+JMfj8MdG3iCLdSq4qEgTnIvePwP6Ii1HdzJymEX/LpHsM6
V9cjAoGAQhlC+mbLck6LkOlXkodiMBjY1ix2/1gVWmyDNt+e222bPzaF5ACIr0A2
eeDy6i545aEt28mO6VsOgqFE+NK2AfRnejyDGYDZTOQIl2J2CkK22b8az2omnoPq
WXAdpLfCiIVjLYzXD6pktOIgBzDeXgfChDHN9+njAjD+9dxBG3A=
-----END RSA PRIVATE KEY-----
EOF
chmod 600 ca-key.pem
ls ca*

#将CA证书文件复制到需要使用的目录
cp ca* /etc/kubernetes/ssl
}
# 下载并配置ETCD
INSTALL_ETCD()
{
    mkdir -p /home/k8s/etcd
    cd /home/k8s/etcd
    
    if [ ! -f /usr/bin/etcd ]; then
        rm etcd*
        wget https://github.com/coreos/etcd/releases/download/v3.2.1/etcd-v3.2.1-linux-amd64.tar.gz
    fi
    
    tar -xvf etcd-v3.2.1-linux-amd64.tar.gz
    cp etcd-v3.2.1-linux-amd64/etcd* /usr/bin/ 

#创建ETCD证书

    cat > etcd-csr.json<<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "${NODE_IP}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

    cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
      -ca-key=/etc/kubernetes/ssl/ca-key.pem \
      -config=/etc/kubernetes/ssl/ca-config.json \
      -profile=kubernetes etcd-csr.json | cfssljson -bare etcd

    ls etcd*

    cp etcd*.pem /etc/etcd/ssl

    rm etcd.csr  etcd-csr.json

    if [ -d /var/lib/etcd ]; then
        rm -rf /var/lib/etcd
    fi
    
    mkdir -p /var/lib/etcd

#创建ETCD服务
    cat > etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/bin/etcd \\
  --name=${NODE_NAME} \\
  --cert-file=/etc/etcd/ssl/etcd.pem \\
  --key-file=/etc/etcd/ssl/etcd-key.pem \\
  --peer-cert-file=/etc/etcd/ssl/etcd.pem \\
  --peer-key-file=/etc/etcd/ssl/etcd-key.pem \\
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --initial-advertise-peer-urls=https://${NODE_IP}:2380 \\
  --listen-peer-urls=https://${NODE_IP}:2380 \\
  --listen-client-urls=https://${NODE_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=https://${NODE_IP}:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=${ETCD_NODES} \\
  --initial-cluster-state=new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    cp etcd.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable etcd
    systemctl restart etcd
    ps aux|grep etcd

read -p "请等待另外两个node的etcd安装完成后，按任意键执行ETCD集群的健康检测！ "

    for ip in ${NODE_IPS}; do
      ETCDCTL_API=3 /usr/bin/etcdctl \
      --endpoints=https://${ip}:2379  \
      --cacert=/etc/kubernetes/ssl/ca.pem \
      --cert=/etc/etcd/ssl/etcd.pem \
      --key=/etc/etcd/ssl/etcd-key.pem \
      endpoint health; done
      }
      
# 下载 kubectl

INSTALL_KUBE()
{
cd /home/k8s

    if [ ! -f /usr/bin/kubectl ]; then
        rm -rf kubernetes*
        wget https://dl.k8s.io/v1.6.4/kubernetes-client-linux-amd64.tar.gz
        tar -xzvf kubernetes-client-linux-amd64.tar.gz
        cp kubernetes/client/bin/kube*  /usr/bin/
        chmod a+x  /usr/bin/kube*
    fi
    
#创建 admin 证书,kubectl 与 kube-apiserver 的安全端口通信，需要为安全通信提供 TLS 证书和秘钥。
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF
     cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
        -ca-key=/etc/kubernetes/ssl/ca-key.pem \
        -config=/etc/kubernetes/ssl/ca-config.json \
        -profile=kubernetes admin-csr.json | cfssljson -bare admin
    ls admin*
    cp admin*.pem /etc/kubernetes/ssl/
    rm admin.csr admin-csr.json
#创建 kubectl kubeconfig 文件
     kubectl config set-cluster kubernetes \
        --certificate-authority=/etc/kubernetes/ssl/ca.pem \
        --embed-certs=true \
        --server=${KUBE_APISERVER}
#设置客户端认证参数
     kubectl config set-credentials admin \
        --client-certificate=/etc/kubernetes/ssl/admin.pem \
        --embed-certs=true \
        --client-key=/etc/kubernetes/ssl/admin-key.pem
#设置上下文参数
    kubectl config set-context kubernetes \
        --cluster=kubernetes \
        --user=admin
#设置默认上下文
    kubectl config use-context kubernetes

#生成的 kubeconfig 被保存到 ~/.kube/config 文件；
#将 ~/.kube/config 文件拷贝到运行 kubelet 命令的机器的 ~/.kube/ 目录下。
}
# 安装配置FLANNEL
FLANNEL_NETWORK()
{
    if [ ! -d /home/k8s/flannel ]; then 
        mkdir -p /home/k8s/flannel
    fi
    cd /home/k8s/flannel
    cat > flanneld-csr.json <<EOF
{
  "CN": "flanneld",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
    cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
      -ca-key=/etc/kubernetes/ssl/ca-key.pem \
      -config=/etc/kubernetes/ssl/ca-config.json \
      -profile=kubernetes flanneld-csr.json | cfssljson -bare flanneld
    ls flanneld*
    cp flanneld*.pem /etc/flanneld/ssl
    rm flanneld.csr flanneld-csr.json
    if [ ! -f /usr/bin/flanneld ]; then
        rm -rf flannel*
        wget https://github.com/coreos/flannel/releases/download/v0.7.1/flannel-v0.7.1-linux-amd64.tar.gz
        mkdir flannel
        tar -xzvf flannel-v0.7.1-linux-amd64.tar.gz -C flannel
    fi
    cp flannel/{flanneld,mk-docker-opts.sh}  /usr/bin/
    etcdctl \
      --endpoints=${ETCD_ENDPOINTS} \
      --ca-file=/etc/kubernetes/ssl/ca.pem \
      --cert-file=/etc/flanneld/ssl/flanneld.pem \
      --key-file=/etc/flanneld/ssl/flanneld-key.pem \
  set ${FLANNEL_ETCD_PREFIX}/config '{"Network":"'${CLUSTER_CIDR}'", "SubnetLen": 24, "Backend": {"Type": "vxlan"}}'
    cat > flanneld.service << EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
ExecStart= /usr/bin/flanneld \\
  -etcd-cafile=/etc/kubernetes/ssl/ca.pem \\
  -etcd-certfile=/etc/flanneld/ssl/flanneld.pem \\
  -etcd-keyfile=/etc/flanneld/ssl/flanneld-key.pem \\
  -etcd-endpoints=${ETCD_ENDPOINTS} \\
  -etcd-prefix=${FLANNEL_ETCD_PREFIX}
ExecStartPost=/usr/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF
    cp flanneld.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable flanneld
    ip link delete docker0
    systemctl restart flanneld
    sleep 10
    ifconfig flannel.1
}

# 安装DOCKER-CE 17.04
Docker()
{
    cd /home/k8s
    if [ ! -f /usr/bin/dockerd ];then 
         rm docker*
         wget https://get.docker.com/builds/Linux/x86_64/docker-17.04.0-ce.tgz
         rm -f /usr/local/bin/docker*
         rm -f /usr/bin/docker*
         tar -xvf docker-17.04.0-ce.tgz
    fi
    cp docker/docker* /usr/bin/
    cp docker/completion/bash/docker /etc/bash_completion.d/
    cat > docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
Environment="PATH=/usr/bin:/bin:/sbin:/usr/bin:/usr/sbin"
EnvironmentFile=-/run/flannel/docker
ExecStart=/usr/bin/dockerd --log-level=error $DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
    sed -i '8,9d' docker.service
    sed -i '/^EnvironmentFile/aExecStart=/usr/bin/dockerd --log-level=error $DOCKER_NETWORK_OPTIONS' docker.service
    sed -i '/^ExecStart/aExecReload=/bin/kill -s HUP $MAINPID' docker.service
    iptables -P FORWARD ACCEPT
    mkdir -p /etc/docker
    cat >/etc/docker/daemon.json<<EOF
{
  "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn", "hub-mirror.c.163.com"],
  "max-concurrent-downloads": 10
}
EOF
    cp docker.service /etc/systemd/system/docker.service
    systemctl daemon-reload
    systemctl enable docker
    iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat
    systemctl restart docker
    /usr/bin/docker version

}
# 配置Kube-apiserver
Kube_apiserver()
{
#下载kubernetes的master文件
    cd /home/k8s
    if [ ! -f /usr/bin/kube-apiserver ];then
        rm  -rf kubernetes*
        wget https://dl.k8s.io/v1.6.4/kubernetes-server-linux-amd64.tar.gz
        tar -xzvf kubernetes-server-linux-amd64.tar.gz
        cd kubernetes && tar -xzvf  kubernetes-src.tar.gz
        cp -r server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubectl,kube-proxy,kubelet} /usr/bin/
    fi
#生成kubernetes证书和私钥
cd /home/k8s
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "${MASTER_IP}",
    "${CLUSTER_KUBERNETES_SVC_IP}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
    cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
      -ca-key=/etc/kubernetes/ssl/ca-key.pem \
      -config=/etc/kubernetes/ssl/ca-config.json \
      -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
    ls kubernetes*
    cp kubernetes*.pem /etc/kubernetes/ssl/

#配置和启动 kube-apiserver
#创建 kube-apiserver 使用的客户端 token 文件。
#kubelet 首次启动时向 kube-apiserver 发送 TLS Bootstrapping 请求，kube-apiserver 验证 kubelet 请求中的 token 是否与它配置的 token.csv 一致，如果一致则自动为 kubelet生成证书和秘钥。
    cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
    cp token.csv /etc/kubernetes/
#创建 kube-apiserver 的 systemd unit 文件
    cat  > kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/bin/kube-apiserver \\
  --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --advertise-address=${MASTER_IP} \\
  --bind-address=${MASTER_IP} \\
  --insecure-bind-address=${MASTER_IP} \\
  --authorization-mode=RBAC \\
  --runtime-config=rbac.authorization.k8s.io/v1alpha1 \\
  --kubelet-https=true \\
  --experimental-bootstrap-token-auth \\
  --token-auth-file=/etc/kubernetes/token.csv \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=${NODE_PORT_RANGE} \\
  --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem \\
  --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \\
  --client-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem \\
  --etcd-cafile=/etc/kubernetes/ssl/ca.pem \\
  --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem \\
  --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem \\
  --etcd-servers=${ETCD_ENDPOINTS} \\
  --enable-swagger-ui=true \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/lib/audit.log \\
  --event-ttl=1h \\
  --v=2
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    cp kube-apiserver.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable kube-apiserver
    systemctl start kube-apiserver
    ps aux|grep kube-apiserver
# 配置和启动 kube-controller-manager
#创建 kube-controller-manager 的 systemd unit 文件
    cd /home/k8s
    cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-controller-manager \\
  --address=127.0.0.1 \\
  --master=http://${MASTER_IP}:8080 \\
  --allocate-node-cidrs=true \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --cluster-cidr=${CLUSTER_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem \\
  --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem \\
  --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem \\
  --root-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --leader-elect=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
#启动 kube-controller-manager
    cp kube-controller-manager.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable kube-controller-manager
    systemctl restart kube-controller-manager
    ps aux|grep kube-controller-manager
# 配置和启动 kube-scheduler
#创建 kube-scheduler 的 systemd unit 文件
    cd /home/k8s
    cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-scheduler \\
  --address=127.0.0.1 \\
  --master=http://${MASTER_IP}:8080 \\
  --leader-elect=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    cp kube-scheduler.service /etc/systemd/system
    systemctl daemon-reload
    systemctl enable kube-scheduler
    systemctl restart kube-scheduler
    ps aux|grep kube-scheduler
    sleep 5
    /usr/bin/kubectl get componentstatuses

}
# 配置kubelet、kube-proxy
Node()
{
#下载1.6.4的 kubelet 和 kube-proxy 二进制文件
    cd /home/k8s
    
    if [ ! -f /usr/bin/kubelet ];then
        rm -rf kubernetes*
        wget https://dl.k8s.io/v1.6.4/kubernetes-server-linux-amd64.tar.gz
        tar -xzvf kubernetes-server-linux-amd64.tar.gz
        cd kubernetes && tar -xzvf  kubernetes-src.tar.gz
        cp -r ./server/bin/{kube-proxy,kubelet} /usr/bin/
    fi
    cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
    cp token.csv /etc/kubernetes/
    kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap
#创建 kubelet bootstrapping kubeconfig 文件
#设置集群参数
    kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/ssl/ca.pem \
      --embed-certs=true \
      --server=${KUBE_APISERVER} \
      --kubeconfig=bootstrap.kubeconfig
#设置客户端认证参数
    kubectl config set-credentials kubelet-bootstrap \
      --token=${BOOTSTRAP_TOKEN} \
      --kubeconfig=bootstrap.kubeconfig
#设置上下文参数
    kubectl config set-context default \
      --cluster=kubernetes \
      --user=kubelet-bootstrap \
      --kubeconfig=bootstrap.kubeconfig
#设置默认上下文
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
cp bootstrap.kubeconfig /etc/kubernetes/
    if [ -d /var/lib/kubelet ]; then
         rm -rf /var/lib/kubelet 
    fi
    mkdir -p /var/lib/kubelet
    cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/bin/kubelet \\
  --address=${NODE_IP} \\
  --hostname-override=${NODE_IP} \\
  --pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest \\
  --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \\
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\
  --require-kubeconfig \\
  --cert-dir=/etc/kubernetes/ssl \\
  --cluster_dns=${CLUSTER_DNS_SVC_IP} \\
  --cluster_domain=${CLUSTER_DNS_DOMAIN} \\
  --hairpin-mode promiscuous-bridge \\
  --allow-privileged=true \\
  --serialize-image-pulls=false \\
  --logtostderr=true \\
  --v=2
ExecStopPost=/sbin/iptables -A INPUT -s 10.0.0.0/8 -p tcp --dport 4194 -j ACCEPT
ExecStopPost=/sbin/iptables -A INPUT -s 172.16.0.0/12 -p tcp --dport 4194 -j ACCEPT
ExecStopPost=/sbin/iptables -A INPUT -s 192.168.0.0/16 -p tcp --dport 4194 -j ACCEPT
ExecStopPost=/sbin/iptables -A INPUT -p tcp --dport 4194 -j DROP
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
#启动 kubelet
    cp kubelet.service /etc/systemd/system/kubelet.service
    rm /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    systemctl daemon-reload
    systemctl enable kubelet
    systemctl restart kubelet
    ps aux|grep kubelet
#配置 kube-proxy
cd /home/k8s
    if [ -d /var/lib/kube-proxy ];then
        rm -rf /var/lib/kube-proxy
    fi
    mkdir -p /var/lib/kube-proxy
    cat > kube-proxy-csr.json<<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
    cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
      -ca-key=/etc/kubernetes/ssl/ca-key.pem \
      -config=/etc/kubernetes/ssl/ca-config.json \
      -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
    ls kube-proxy*
    cp kube-proxy*.pem /etc/kubernetes/ssl/
#创建 kube-proxy kubeconfig 文件
    kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/ssl/ca.pem \
      --embed-certs=true \
      --server=${KUBE_APISERVER} \
      --kubeconfig=kube-proxy.kubeconfig
#设置客户端认证参数
    kubectl config set-credentials kube-proxy \
      --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
      --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
      --embed-certs=true \
      --kubeconfig=kube-proxy.kubeconfig
#设置上下文参数
    kubectl config set-context default \
      --cluster=kubernetes \
      --user=kube-proxy \
      --kubeconfig=kube-proxy.kubeconfig
#设置默认上下文
    kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
    cp kube-proxy.kubeconfig /etc/kubernetes/

    cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=/var/lib/kube-proxy
ExecStart=/usr/bin/kube-proxy \\
  --bind-address=${NODE_IP} \\
  --hostname-override=${NODE_IP} \\
  --cluster-cidr=${SERVICE_CIDR} \\
  --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
#启动 kube-proxy
    cp kube-proxy.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable kube-proxy
    systemctl start kube-proxy
    ps aux|grep kube-proxy
}
# 安装dashboard插件
Dashboard()
{
    mkdir -p /home/k8s/dashboard
    cp /home/k8s/kubernetes/cluster/addons/dashboard/*.yaml /home/k8s/dashboard/
    cd /home/k8s/dashboard/
    sed -i '/^spec:/a\  type: NodePort' dashboard-service.yaml
    sed -i '/containers:/i\      serviceAccountName: dashboard' dashboard-controller.yaml
    sed -i 's/gcr.io\/google_containers/cokabug/g' dashboard-controller.yaml
    cat >dashboard-rbac.yaml<<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard
  namespace: kube-system

---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1alpha1
metadata:
  name: dashboard
subjects:
  - kind: ServiceAccount
    name: dashboard
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
    kubectl create -f .
    kubectl get pods -n kube-system
}
# 部署 heapster 插件
HEAPSTER()
{
    mkdir -p /home/k8s/heapster
    cd /home/k8s/heapster
    
    if [ ! -d heapster-1.4.0 ];then 
        rm -rf heapster*
        wget https://codeload.github.com/kubernetes/heapster/tar.gz/v1.4.0 -O heapster-1.4.0.tar.gz
    fi
    
    tar -zxvf heapster-1.4.0.tar.gz
    cd heapster-1.4.0/deploy/kube-config/influxdb
    cp /home/k8s/heapster/heapster-1.4.0/deploy/kube-config/rbac/heapster-rbac.yaml ./
    sed -i 's/gcr.io\/google_containers/lvanneo/g' grafana.yaml
    sed -i 's/# value:/value:/g' grafana.yaml
    sed -i 's/v4.2.0/v4.0.2/g' grafana.yaml
    sed -i 's/value: \/$/# value: \//g' grafana.yaml
    sed -i 's/gcr.io\/google_containers/lvanneo/g' heapster.yaml
    sed -i 's/v1.3.0/v1.3.0-beta.1/g' heapster.yaml
    sed -i 's/gcr.io\/google_containers/lvanneo/g' influxdb.yaml
    kubectl create -f .
    kubectl get pods -n kube-system
}
# 安装Dns插件
DNS()
{
    mkdir -p /home/k8s/dns
    rm /home/k8s/dns/*
    cp /home/k8s/kubernetes/cluster/addons/dns/kubedns-cm.yaml /home/k8s/dns/
    cp /home/k8s/kubernetes/cluster/addons/dns/kubedns-sa.yaml /home/k8s/dns/
    cp /home/k8s/kubernetes/cluster/addons/dns/kubedns-controller.yaml.base /home/k8s/dns/kubedns-controller.yaml
    cp /home/k8s/kubernetes/cluster/addons/dns/kubedns-svc.yaml.base /home/k8s/dns/kubedns-svc.yaml
    cd /home/k8s/dns
#替换dns服务ip
    sed -i 's/__PILLAR__DNS__SERVER__/10.254.0.2/g' kubedns-svc.yaml
#由于谷歌镜像被强，所以替换镜像
    sed -i 's/gcr.io\/google_containers/xuejipeng/g' kubedns-controller.yaml
    sed -i 's/__PILLAR__DNS__DOMAIN__\/127.0.0.1/cluster.local.\/127.0.0.1/g' kubedns-controller.yaml
    sed -i 's/kubernetes.default.svc.__PILLAR__DNS__DOMAIN__/kubernetes.default.svc.cluster.local./g' kubedns-controller.yaml
    sed -i 's/__PILLAR__FEDERATIONS__DOMAIN__MAP__/#__PILLAR__FEDERATIONS__DOMAIN__MAP__/g' kubedns-controller.yaml
    sed -i 's/1.14.1/v1.14.1/g' kubedns-controller.yaml
    sed -i 's/domain=__PILLAR__DNS__DOMAIN__/domain=cluster.local/g'  kubedns-controller.yaml
    kubectl create -f .
    kubectl get pods -n kube-system
}

EFK()
{
mkidr -p /home/k8s/efk
cp /home/k8s/kubernetes/cluster/addons/fluentd-elasticsearch/*.yaml /home/k8s/efk/
cd /home/k8s/efk
sed -i 's/gcr.io\/google_containers/onlyerich/g' *.yaml
sed -i '/containers:/i\      serviceAccountName: fluentd'  fluentd-es-ds.yaml
sed -i '/containers:/i\      serviceAccountName: elasticsearch' es-controller.yaml
cat > es-rbac.yaml <<EOF 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: elasticsearch
  namespace: kube-system

---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1alpha1
metadata:
  name: elasticsearch
subjects:
  - kind: ServiceAccount
    name: elasticsearch
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF

cat > fluentd-es-rbac.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: kube-system

---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1alpha1
metadata:
  name: fluentd
subjects:
  - kind: ServiceAccount
    name: fluentd
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF

for nx in $(kubectl get nodes |awk '{print $1}'|grep -v NAME); do kubectl label nodes $nx beta.kubernetes.io/fluentd-ds-ready=true; done
kubectl create -f .
}
Traefik()
{
mkdir -p /home/k8s/traefik

cd /home/k8s/traefik && rm -rf *

#创建Traefik的rbac用于api交互
wget https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik-rbac.yaml

#创建Traefik的Deployment 
wget https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/traefik.yaml

#创建Traefik的web ui
wget https://raw.githubusercontent.com/containous/traefik/master/examples/k8s/ui.yaml

kubectl delete -f . > /dev/null

kubectl create -f .

sleep 10

kubectl get pods -n kube-system |grep traefik


echo "在你的电脑的hosts或者dns上添加traefik-ui.minikube域名指向k8s-master的ip"
echo "或者在你的电脑使用一下命令"echo "\$MASTER_IP  traefik-ui.minikube" \| sudo tee -a /etc/hosts""
echo "上面的步骤完成后，在浏览器里访问http://traefik-ui.minikube"
echo "具体实例请参考https://github.com/containous/traefik/blob/master/docs/user-guide/kubernetes.md"

}

# 安装Harbor
Harbor()
{
    if [ ! -f /usr/local/bin/docker-compose ];then
       curl -L https://github.com/docker/compose/releases/download/1.14.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
    fi
    
    if [ ! -f /usr/bin/python ];then
    apt-get install python -y
    yum install python -y
    fi
    cd /home/k8s/
    echo "Download harbor-offline-installer-v1.1.2.tgz ...... "
    
    if [ ! -d harbor ];then
        rm -rf harbor*
        wget  --continue  https://github.com/vmware/harbor/releases/download/v1.1.2/harbor-offline-installer-v1.1.2.tgz
        tar -xzvf harbor-offline-installer-v1.1.2.tgz
        cd harbor
        docker load -i harbor.v1.1.2.tar.gz
    fi
    
    cd harbor
    cat > harbor-csr.json <<EOF
{
  "CN": "harbor",
  "hosts": [
    "127.0.0.1",
    "$NODE_IP"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

    cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
      -ca-key=/etc/kubernetes/ssl/ca-key.pem \
      -config=/etc/kubernetes/ssl/ca-config.json \
      -profile=kubernetes harbor-csr.json | cfssljson -bare harbor

    mkdir -p /etc/harbor/ssl

    cp harbor*.pem /etc/harbor/ssl

    cat >harbor.cfg<<EOF
## Configuration file of Harbor

#The IP address or hostname to access admin UI and registry service.
#DO NOT use localhost or 127.0.0.1, because Harbor needs to be accessed by external clients.
hostname = $NODE_IP

#The protocol for accessing the UI and token/notification service, by default it is http.
#It can be set to https if ssl is enabled on nginx.
ui_url_protocol = https

#The password for the root user of mysql db, change this before any production use.
db_password = root123

#Maximum number of job workers in job service
max_job_workers = 3

#Determine whether or not to generate certificate for the registry's token.
#If the value is on, the prepare script creates new root cert and private key
#for generating token to access the registry. If the value is off the default key/cert will be used.
#This flag also controls the creation of the notary signer's cert.
customize_crt = on

#The path of cert and key files for nginx, they are applied only the protocol is set to https
ssl_cert = /etc/harbor/ssl/harbor.pem
ssl_cert_key = /etc/harbor/ssl/harbor-key.pem

#The path of secretkey storage
secretkey_path = /data

#Admiral's url, comment this attribute, or set its value to NA when Harbor is standalone
admiral_url = NA

#NOTES: The properties between BEGIN INITIAL PROPERTIES and END INITIAL PROPERTIES
#only take effect in the first boot, the subsequent changes of these properties
#should be performed on web ui

#************************BEGIN INITIAL PROPERTIES************************

#Email account settings for sending out password resetting emails.

#Email server uses the given username and password to authenticate on TLS connections to host and act as identity.
#Identity left blank to act as username.
email_identity =

email_server = smtp.mydomain.com
email_server_port = 25
email_username = sample_admin@mydomain.com
email_password = abc
email_from = admin <sample_admin@mydomain.com>
email_ssl = false

##The initial password of Harbor admin, only works for the first time when Harbor starts.
#It has no effect after the first launch of Harbor.
#Change the admin password from UI after launching Harbor.
harbor_admin_password = Harbor12345

##By default the auth mode is db_auth, i.e. the credentials are stored in a local database.
#Set it to ldap_auth if you want to verify a user's credentials against an LDAP server.
auth_mode = db_auth

#The url for an ldap endpoint.
ldap_url = ldaps://ldap.mydomain.com

#A user's DN who has the permission to search the LDAP/AD server.
#If your LDAP/AD server does not support anonymous search, you should configure this DN and ldap_search_pwd.
#ldap_searchdn = uid=searchuser,ou=people,dc=mydomain,dc=com

#the password of the ldap_searchdn
#ldap_search_pwd = password

#The base DN from which to look up a user in LDAP/AD
ldap_basedn = ou=people,dc=mydomain,dc=com

#Search filter for LDAP/AD, make sure the syntax of the filter is correct.
#ldap_filter = (objectClass=person)

# The attribute used in a search to match a user, it could be uid, cn, email, sAMAccountName or other attributes depending on your LDAP/AD
ldap_uid = uid

#the scope to search for users, 1-LDAP_SCOPE_BASE, 2-LDAP_SCOPE_ONELEVEL, 3-LDAP_SCOPE_SUBTREE
ldap_scope = 3

#Timeout (in seconds)  when connecting to an LDAP Server. The default value (and most reasonable) is 5 seconds.
ldap_timeout = 5

#Turn on or off the self-registration feature
self_registration = on

#The expiration time (in minute) of token created by token service, default is 30 minutes
token_expiration = 30

#The flag to control what users have permission to create projects
#The default value "everyone" allows everyone to creates a project.
#Set to "adminonly" so that only admin user can create project.
project_creation_restriction = everyone

#Determine whether the job service should verify the ssl cert when it connects to a remote registry.
#Set this flag to off when the remote registry uses a self-signed or untrusted certificate.
verify_remote_cert = on
#************************END INITIAL PROPERTIES************************
EOF
    mkdir -p /etc/docker/certs.d/$NODE_IP
    cp /etc/kubernetes/ssl/ca.pem /etc/docker/certs.d/$NODE_IP/ca.crt
    cat >>install.sh<<EOF
echo " 
  1、harbor 登陆用户名: admin ,默认密码: Harbor12345
  2、日志目: /var/log/harbor/ ,数据镜像目录: /data/ 
  3、启动 harbor的命令为:/home/k8s/harbor/docker-compose up -d
  4、停止 harbor的命令为:/home/k8s/harbor/docker-compose down -v
  5、修改harbor.cfg文件后必须在/home/k8s/harbor/目录下用./prepare更新到 docker-compose.yml 文件"
EOF

./install.sh &

}


echo -n "选择要安装的角色"Etcd","Master","Node","add-nodes","traefik","Harbor","cleanall":  "
read answer
    if [ "$answer" == "Master" ]; then
          INSTALL_KUBE
          FLANNEL_NETWORK
          Docker
          Kube_apiserver
          Node
          ADD_NODES
          DNS
          Dashboard
          HEAPSTER
    else 
        if  [ "$answer" == "Node" ]; then
            INSTALL_KUBE
            FLANNEL_NETWORK
            Docker
            Node
        elif [ "$answer" == "add-nodes" ]; then
            ADD_NODES
	elif [ "$answer" == "traefik" ]; then
            Traefik
        elif [ "$answer" == "Etcd" ]; then
             CREATE_CA
             INSTALL_ETCD
        elif [ "$answer" == "cleanall" ]; then
            Clean_all
        elif [ "$answer" == "Harbor" ]; then
            Harbor
        fi
    fi
