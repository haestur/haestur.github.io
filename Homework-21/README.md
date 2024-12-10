## OTUS Linux Professional - Урок 30. Фильтрация трафика - iptables.

#### ЦЕЛЬ: Написать сценарии iptables.

#### ЗАДАЧИ:
1. реализовать knocking port (centralRouter может попасть на ssh inetrRouter через knock скрипт);
2. добавить inetRouter2, который виден(маршрутизируется (host-only тип сети для виртуалки)) с хоста или форвардится порт через локалхост;
3. запустить nginx на centralServer;
4. пробросить 80й порт на inetRouter2 8080;
5. дефолт в инет оставить через inetRouter;

> [!TIP]
> В данном репозитории все задачи выполняются с помощью Ansible при создании виртуальных машин командой vagrant up

#### ЗАДАЧА 1:
_Настроить "knocking port" на роутере inetRouter. Результат: к роутеру inetRouter можно подключиться по ssh только если предварительно последовательно постучаться на порты tcp/8881, tcp/7777, tcp/9991._

Подключаемся к роутеру inetRouter:
```console
$ vagrant ssh inetRouter
```
Отключаем ufw:
```console
root@inetRouter:~# systemctl stop ufw
root@inetRouter:~# systemctl disable ufw
```
Устанавливаем пакеты для сохранения правил iptables:
```console
root@inetRouter:~# apt install netfilter-persistent iptables-persistent
```
Включаем маскарадинг:
```console
root@inetRouter:~# iptables -t nat -A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE
```
Настраиваем правила для реализации port knocking:
```console
root@inetRouter:~# iptables -N TRAFFIC
root@inetRouter:~# iptables -N SSH-INPUT
root@inetRouter:~# iptables -N SSH-INPUTTWO
root@inetRouter:~# iptables -A TRAFFIC -p icmp --icmp-type any -j ACCEPT
root@inetRouter:~# iptables -A TRAFFIC -m state --state ESTABLISHED,RELATED -j ACCEPT
root@inetRouter:~# iptables -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 22 -m recent --rcheck --seconds 30 --name SSH2 -j ACCEPT
root@inetRouter:~# iptables -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH2 --remove -j DROP
root@inetRouter:~# iptables -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 9991 -m recent --rcheck --name SSH1 -j SSH-INPUTTWO
root@inetRouter:~# iptables -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH1 --remove -j DROP
root@inetRouter:~# iptables -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 7777 -m recent --rcheck --name SSH0 -j SSH-INPUT
root@inetRouter:~# iptables -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH0 --remove -j DROP
root@inetRouter:~# iptables -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 8881 -m recent --name SSH0 --set -j DROP
root@inetRouter:~# iptables -A SSH-INPUT -m recent --name SSH1 --set -j DROP
root@inetRouter:~# iptables -A SSH-INPUTTWO -m recent --name SSH2 --set -j DROP
root@inetRouter:~# iptables -A INPUT -i eth1 -j TRAFFIC
root@inetRouter:~# iptables -A TRAFFIC -i eth1 -j DROP
```
Сохраняем правила:
```console
root@inetRouter:~# netfilter-persistent save
```
Проверяем. Делаем попытку подключиться по ssh с centralRouter на inetRouter:
```console
vagrant@centralRouter:~$ ssh root@192.168.255.1
```
Видим что подключится не удается. Пробуем теперь постучаться последовательно на порты tcp/8881, tcp/7777, tcp/9991, и после этого подключиться по ssh:
```console
vagrant@centralRouter:~$ nmap -Pn --host-timeout 100 --max-retries 0 -p 8881 192.168.255.1
vagrant@centralRouter:~$ nmap -Pn --host-timeout 100 --max-retries 0 -p 7777 192.168.255.1
vagrant@centralRouter:~$ nmap -Pn --host-timeout 100 --max-retries 0 -p 9991 192.168.255.1

vagrant@centralRouter:~$ ssh root@192.168.255.1
root@192.168.255.1's password: 
```
Подключение по ssh работает. Значит port knocking настроен верно. 
Чтобы не стучать каждый раз вручную (не вводить несколько команд), можно сделать скрипт:
```shell
#!/bin/bash
HOST=$1
shift
for ARG in "$@"
do
        nmap -Pn --host-timeout 100 --max-retries 0 -p $ARG $HOST
done
```
и запускать перед подключением по ssh `knock HOST PORT1 PORT2 PORTx`. Например:
```console
$ knock 192.168.255.1 8881 7777 9991
```
#### ЗАДАЧА 2: 
_Добавить inetRouter2, который виден(маршрутизируется (host-only тип сети для виртуалки)) с хоста или форвардится порт через локалхост_

Добавляем в нашу схему виртуальную машину inetRouter2 с сетевой адресацией, указанной на схеме. Изменения отображены в Vagrantfile. 

#### ЗАДАЧА 3: 
_Запустить nginx на centralServer_

Подключаемся к centralServer. Устанавливаем и запускаем nginx:
```console
root@centralServer:~# apt update
root@centralServer:~# apt install nginx
root@centralServer:~# systemctl enable --now nginx
```

#### ЗАДАЧА 4:
_Пробросить 80й порт на inetRouter2 8080. То есть при подключении с хоста на inet2Router по http:192.168.56.2:8080  трафик должен перенаправиться на centralServer порт 192.168.1.2:80_

Подключаемся к inet2Router.

Отключаем ufw:
```console
root@inetRouter:~# systemctl stop ufw
root@inetRouter:~# systemctl disable ufw
```
Устанавливаем пакеты для сохранения правил iptables:
```console
root@inetRouter:~# apt install netfilter-persistent iptables-persistent
```
Включаем маршрутизацию транзитных пакетов:
```console
root@inet2Router:~# echo "net.ipv4.conf.all.forwarding = 1" >> /etc/sysctl.conf
root@inet2Router:~# sysctl -p
```
Настраиваем DNAT:
```console
root@inet2Router:~# iptables -t nat -I PREROUTING 1 -i eth2 -p tcp --dport 8080 -j DNAT --to-destination 192.168.1.2:80
```
Включаем маскарадинг:
```console
root@inet2Router:~# iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE
```
На centralServer добавляем статический маршрут к сети 192.168.56.0/24 через inet2Router:
```console
vagrant@centralServer:~$ vim /etc/netplan/50-vagrant.yaml
```
```yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
      - 192.168.0.2/30
    eth2:
      addresses:
      - 192.168.1.2/30
      routes:
      - to: 192.168.56.0/24
        via: 192.168.1.1
```
```console
root@centralServer:~# netplan try
```
Для проверки заходим в браузере на хосте по адресу http://192.168.56.2:8080. Если видим приглашение от nginx, значит проброс работает.

#### ЗАДАЧА 5: 
_Маршрут по умолчанию для centralServer и centralRouter настроить через inetRouter_

На centralServer добавляем маршрут по умолчанию через centralRouter. 
Отключаем получение маршрута по умолчанию по DHCP:
```console
root@centralServer:~# vim /etc/netplan/00-installer-config.yaml
```
```yaml
# This is the network config written by 'subiquity'
network:
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
        use-routes: false
      dhcp6: false
  version: 2

```
Добавляем статический маршрут по умолчанию через centralRouter:
```console
root@centralServer:~# vim /etc/netplan/50-vagrant.yaml
```
```yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
      - 192.168.0.2/30
      routes:
      - to: 0.0.0.0/0
        via: 192.168.0.1
    eth2:
      addresses:
      - 192.168.1.2/30
      routes:
      - to: 192.168.56.0/24
        via: 192.168.1.1
```
```console
root@centralServer:~# netplan try
```
Те же действия выполняем на centralServer.

Для проверки заходим на centralServer и выполняем traceroute:
```console
vagrant@centralServer:~$ traceroute -n 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  192.168.0.1  0.857 ms  0.767 ms  0.726 ms
 2  192.168.255.1  1.591 ms  1.461 ms  1.421 ms
 3  10.0.2.2  2.151 ms  2.114 ms  2.074 ms
 4  * * *
 5  * * *
...
...
...
```
