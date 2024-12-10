## OTUS Linux Professional - Урок 35. Мосты, туннели и VPN.

#### ЦЕЛЬ: Научится настраивать VPN-сервер в Linux-based системах

#### Описание домашнего задания:
1. Настроить VPN между двумя ВМ в tun/tap режимах, замерить скорость в туннелях, сделать вывод об отличающихся показателях
2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на ВМ
3. (*) Самостоятельно изучить и настроить ocserv, подключиться с хоста к ВМ

#### Инструкция по выполнению ДЗ:
1. __Настроить VPN между двумя ВМ в tun/tap режимах__
   Запускаем 2 виртуальные машины с помощью Vagrant - host1 и host2
   ```console
   # vagrant up host1
   # vagrant up host2
   ```
   Устанавливаем необходимые пакеты на двух серверах и отключаем Selinux:
   ```console
   # apt update
   # apt install openvpn iperf3 selinux-utils
   # setenforce 0
   ```
   __Настраиваем host1__
   
   Cоздаем файл-ключ:
   ```console
   root@host1:~# openvpn --genkey secret /etc/openvpn/static.key
   root@host1:~# cp /etc/openvpn/static.key /vagrant/
   ```
   Cоздаем конфигурационный файл OpenVPN /etc/openvpn/server.conf со следующим содержимым:
   ```
   dev tap 
   ifconfig 10.10.10.1 255.255.255.0 
   topology subnet 
   secret /etc/openvpn/static.key 
   comp-lzo 
   status /var/log/openvpn-status.log 
   log /var/log/openvpn.log  
   verb 3 
   ```
   Создаем service unit для запуска OpenVPN /etc/systemd/system/openvpn@.service со следующим содержимым:
   ```
   [Unit] 
   Description=OpenVPN Tunneling Application On %I 
   After=network.target 
   [Service] 
   Type=notify 
   PrivateTmp=true 
   ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf 
   [Install] 
   WantedBy=multi-user.target
   ```
   Запускаем сервис:
   ```console
   root@host1:~# systemctl start openvpn@server
   root@host1:~# systemctl enable openvpn@server
   ```

   __Настраиваем host2__

   Cоздаем конфигурационный файл OpenVPN /etc/openvpn/server.conf со следующим содержимым:
   ```
   dev tap 
   remote 192.168.56.10 
   ifconfig 10.10.10.2 255.255.255.0 
   topology subnet 
   route 192.168.56.0 255.255.255.0 
   secret /etc/openvpn/static.key
   comp-lzo
   status /var/log/openvpn-status.log 
   log /var/log/openvpn.log 
   verb 3 
   ```
   Копируем в директорию /etc/openvpn файл-ключ static.key, который был создан на сервере:
   ```console
   root@host2:~# cp /vagrant/static.key /etc/openvpn/
   ```
   Создаем service unit для запуска OpenVPN /etc/systemd/system/openvpn@.service со следующим содержимым:
   ```
   [Unit] 
   Description=OpenVPN Tunneling Application On %I 
   After=network.target 
   [Service] 
   Type=notify 
   PrivateTmp=true 
   ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf 
   [Install] 
   WantedBy=multi-user.target
   ```
   Запускаем сервис:
   ```console
   root@host2:~# systemctl start openvpn@server
   root@host2:~# systemctl enable openvpn@server
   ```
   Замеряем скорость в туннеле. На host1 запускаем:
   ```console
   root@host1:~# iperf3 -s
   ```
   На host2:
   ```console
   root@host2:~# iperf3 -c 10.10.10.1 -t 40 -i 5
   ...
   ...
   [  5]   0.00-25.00  sec  1.02 GBytes   350 Mbits/sec  755             sender
   [  5]   0.00-25.00  sec  0.00 Bytes  0.00 bits/sec                  receiver
   ```
   И в обратную сторону:
   ```console
   root@host2:~# iperf3 -c 10.10.10.1 -t 40 -i 5 -R
   ...
   ...
   [  5]   0.00-15.59  sec  0.00 Bytes  0.00 bits/sec                  sender
   [  5]   0.00-15.59  sec   549 MBytes   295 Mbits/sec                  receiver
   ```

   Меняем в конфигурационных файлах режим работы с tap на tun.  Замеряем скорость соединения:
   ```console
   root@host2:~# iperf3 -c 10.10.10.1 -t 40 -i 5
   ...
   ...
   [  5]   0.00-40.00  sec  1.54 GBytes   332 Mbits/sec  859             sender
   [  5]   0.00-40.06  sec  1.54 GBytes   331 Mbits/sec                  receiver
   ...
   ...
   ```
   И в обратную сторону:
   ```console
   root@host2:~# iperf3 -c 10.10.10.1 -t 40 -i 5 -R
   ...
   ...
   [  5]   0.00-40.04  sec  1.43 GBytes   308 Mbits/sec  234             sender
   [  5]   0.00-40.00  sec  1.43 GBytes   307 Mbits/sec                  receiver
   ...
   ...
   ```
   __Выводы:__ Видим что разницы в пропускной способности между tun и tap режимом нет - ~ 300 Mbit/s. Основное отличие между tun и tap, это то что tap работает на L2, а tun на L3. tap может быть полезен, 
   например, когда в туннельной сети есть тонкие клиенты или устройства с загрузкой по сети. 
   Без VPN туннеля пропускная способность гораздо выше:
   ```console
   root@host2:~# iperf3 -c 192.168.56.10 -t 40 -i 5
   Connecting to host 192.168.56.10, port 5201
   [  5] local 192.168.56.20 port 36542 connected to 192.168.56.10 port 5201      
   - - - - - - - - - - - - - - - - - - - - - - - - -
   [ ID] Interval           Transfer     Bitrate         Retr
   [  5]   0.00-40.00  sec  24.4 GBytes  5.23 Gbits/sec  109372             sender
   [  5]   0.00-40.05  sec  24.4 GBytes  5.23 Gbits/sec                  receiver


   ```
3. __RAS на базе OpenVPN__

   Поднимаем две виртуальных машины "server" и "client".  
   ```console
   # vagrant up server
   # vagrant up client
   ```
   Устанавливаем необходимые пакеты:
   ```console
   root@server:~# apt update
   root@server:~# apt install openvpn easy-rsa selinux-utils
   ```
   Отключаем SELinux.
   
   Переходим в директорию /etc/openvpn и инициализируем PKI:
   ```console
   root@server:~# cd /etc/openvpn
   root@server:/etc/openvpn# /usr/share/easy-rsa/easyrsa init-pki
   ```
   Генерируем необходимые ключи и сертификаты для сервера:
   ```console
   root@server:/etc/openvpn# /usr/share/easy-rsa/easyrsa build-ca nopass
   root@server:/etc/openvpn# echo 'rasvpn' | /usr/share/easy-rsa/easyrsa gen-req server nopass
   root@server:/etc/openvpn# echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req server server
   root@server:/etc/openvpn# /usr/share/easy-rsa/easyrsa gen-dh
   root@server:/etc/openvpn# openvpn --genkey secret ca.key
   ```
   Генерируем необходимые ключи и сертификаты для клиента:
   ```console
   root@server:/etc/openvpn# echo 'client' | /usr/share/easy-rsa/easyrsa gen-req client nopass
   root@server:/etc/openvpn# echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req client client
   root@server:/etc/openvpn# cp /etc/openvpn/pki/issued/client.crt /vagrant
   root@server:/etc/openvpn# cp /etc/openvpn/pki/private/client.key /vagrant
   root@server:/etc/openvpn# cp /etc/openvpn/pki/ca.crt /vagrant
   ```
   Создаем конфигурационный файл сервера /etc/openvpn/server.conf:
   ```
   port 1207 
   proto udp 
   dev tun 
   ca /etc/openvpn/pki/ca.crt 
   cert /etc/openvpn/pki/issued/server.crt 
   key /etc/openvpn/pki/private/server.key 
   dh /etc/openvpn/pki/dh.pem 
   server 10.10.10.0 255.255.255.0 
   ifconfig-pool-persist ipp.txt 
   client-to-client 
   client-config-dir /etc/openvpn/client 
   keepalive 10 120 
   comp-lzo 
   persist-key 
   persist-tun 
   status /var/log/openvpn-status.log 
   log /var/log/openvpn.log 
   verb 3
   ```
   Зададим параметр iroute для клиента:
   ```console
   root@server:/etc/openvpn# echo 'iroute 10.10.10.0 255.255.255.0' > /etc/openvpn/client/client
   ```
   Запускаем сервис (при необходимости создать файл юнита как в задании 1):
   ```console
   root@server:/etc/openvpn# systemctl start openvpn@server
   root@server:/etc/openvpn# systemctl enable openvpn@server
   ```
   На __клиенте__ создаем файл /etc/openvpn/client.conf со следующим содержимым:
   ```
   dev tun 
   proto udp 
   remote 192.168.56.30 1207 
   client 
   resolv-retry infinite 
   remote-cert-tls server 
   ca ./ca.crt 
   cert ./client.crt 
   key ./client.key 
   route 10.10.10.0 255.255.255.0 
   persist-key 
   persist-tun 
   comp-lzo 
   verb 3 
   ```
   Копируем в одну директорию с client.conf файлы с сервера:
   ```console
   root@client:/etc/openvpn# cd /etc/openvpn
   root@client:/etc/openvpn# cp /vagrant/ca.crt .
   root@client:/etc/openvpn# cp /vagrant/client.crt .
   root@client:/etc/openvpn# cp /vagrant/client.key .
   ```
   Далее можно проверить подключение с помощью:
   ```console
   root@client:/etc/openvpn# openvpn --config client.conf
   ```
   При успешном подключении проверяем пинг по внутреннему IP адресу  сервера в туннеле:
   ```console
   vagrant@client:~$ ping -c 4 10.10.10.1
   PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
   64 bytes from 10.10.10.1: icmp_seq=1 ttl=63 time=0.621 ms
   64 bytes from 10.10.10.1: icmp_seq=2 ttl=63 time=0.719 ms
   64 bytes from 10.10.10.1: icmp_seq=3 ttl=63 time=0.656 ms
   64 bytes from 10.10.10.1: icmp_seq=4 ttl=63 time=0.660 ms

   --- 10.10.10.1 ping statistics ---
   4 packets transmitted, 4 received, 0% packet loss, time 3064ms
   rtt min/avg/max/mdev = 0.621/0.664/0.719/0.035 ms
   ```
   Также проверяем командой ip r (netstat -rn) на хостовой машине что сеть туннеля импортирована в таблицу маршрутизации:
   ```console
   root@client:~# ip r
   default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100 
   10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100 
   10.0.2.2 dev enp0s3 proto dhcp scope link src 10.0.2.15 metric 100 
   10.0.2.3 dev enp0s3 proto dhcp scope link src 10.0.2.15 metric 100 
   10.10.10.0/24 via 10.10.10.5 dev tun0 
   10.10.10.5 dev tun0 proto kernel scope link src 10.10.10.6 
   ```
