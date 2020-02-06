#!/bin/bash

function installVPN(){
        echo "begin to install VPN services";
        #check wether vps suppot ppp and tun

        #判断centos版本
        if grep -Eqi "release 5." /etc/redhat-release; then
                ver1='5'
        elif grep -Eqi "release 6." /etc/redhat-release; then
                ver1='6'
        elif grep -Eqi "release 7." /etc/redhat-release; then
                ver1='7'
        fi

        yum install curl -y
        yum install epel-release -y

        if [ "$ver1" == "7" ]; then
                #centos7需要加这个权限，否则不会开机自动执行
                chmod +x /etc/rc.d/rc.local
        fi

        #先删除已经安装的pptpd和ppp
        rm -rf /etc/pptpd.conf
        rm -rf /etc/ppp



        yum install -y ppp pptpd

        #写配置文件
        mknod /dev/ppp c 108 0 
        echo 1 > /proc/sys/net/ipv4/ip_forward 
        echo "mknod /dev/ppp c 108 0" >> /etc/rc.local
        echo "echo 1 > /proc/sys/net/ipv4/ip_forward" >> /etc/rc.local
        echo "localip 172.16.36.1" >> /etc/pptpd.conf
        echo "remoteip 172.16.36.2-254" >> /etc/pptpd.conf
        echo "ms-dns 10.0.5.99" >> /etc/ppp/options.pptpd
        echo "ms-dns 114.114.114.114" >> /etc/ppp/options.pptpd

        pass=`openssl rand 6 -base64`
        if [ "$1" != "" ]
        then pass=$1
        fi

        echo "vpn pptpd ${pass} *" >> /etc/ppp/chap-secrets
        cat > /usr/lib/firewalld/services/pptpd.xml << EOF
<?xml version="1.0" encoding="utf-8"?>

<service>

       <short>pptpd</short>

       <description>PPTP</description>

       <port protocol="tcp" port="1723"/>

</service>
EOF

        systemctl restart firewalld.service
        firewall-cmd --premanent --zone=public --add-service=http
        firewall-cmd --permanent --zone=public --add-service=pptpd
        firewall-cmd --add-masquerade

        firewall-cmd --permanent --zone=public --add-port=47/tcp
        firewall-cmd --permanent --zone=public --add-port=1723/tcp

        firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -p gre -j ACCEPT
        firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -p gre -j ACCEPTfirewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i ppp+ -o eth0 -j ACCEPT

        firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i eth0 -o ppp+ -j ACCEPTfirewall-cmd --permanent --direct --passthrough ipv4 -t nat -I POSTROUTING -o eth0 -j MASQUERADE -s 172.16.36.0/24

        # windows上关闭vpn高级选项下的允许通过流量计费的网络进行vpn连接，关闭允许漫游时进行vpn连接
        # pptpd上网问题可以百度
        # iptables -A FORWARD -p tcp --syn -s <client-ip-cird>/24 -j TCPMSS --set-mss 1356 

        firewall-cmd --reload


        if [ "ver1" == "7" ]; then
                systemctl enable pptpd.service
                systemctl restart pptpd.service
        else
                chkconfig pptpd on
                service pptpd start
        fi



        echo "================================================"
        echo "感谢使用www.91yun.org提供的pptpd vpn一键安装包"
        echo -e "VPN的初始用户名是：\033[41;37m vpn  \033[0m, 初始密码是： \033[41;37m ${pass}  \033[0m"
        echo "你也可以直接 vi /etc/ppp/chap-secrets修改用户名和密码"
        echo "================================================"
}

function addVPNuser(){
        echo "input user name:"
        read username
        echo "input password:"
        read userpassword
        echo "${username} pptpd ${userpassword} *" >> /etc/ppp/chap-secrets
        service iptables restart
        service pptpd start
}

echo "which do you want to?input the number."
echo "1. install VPN service"
echo "2. add VPN user"
read num

case "$num" in
[1] ) (installVPN);;
[2] ) (addVPNuser);;
*) echo "nothing,exit";;
esac
