## OTUS Linux Professional - Урок 38. LDAP. Централизованная авторизация и аутентификация.

#### ЦЕЛЬ: Научиться настраивать LDAP-сервер и подключать к нему LDAP-клиентов

#### Описание домашнего задания:
1) Установить FreeIPA
2) Написать Ansible-playbook для конфигурации клиента

Дополнительное задание:

3) *Настроить аутентификацию по SSH-ключам

4) **Firewall должен быть включен на сервере и на клиенте

### Инструкция по выполнению домашнего задания:

Создаем 3 виртуальных машины с ОС CentOS 8 Stream:
```console
# vagrant up
```
__Настройка FreeIPA-сервер _ipa.otus.lan_.__
Установим часовой пояс:
```console
[root@ipa ~]# timedatectl set-timezone Europe/Moscow
```
Установим утилиту chrony:
```console
[root@ipa ~]# yum install -y chrony
[root@ipa ~]# systemctl enable chronyd --now
```
Выключаем Firewall:
```console
[root@ipa ~]# systemctl stop firewalld
[root@ipa ~]# systemctl disable firewalld
```
Остановим Selinux:
```console
[root@ipa ~]# setenforce 0
```
Поменяем в файле /etc/selinux/config, параметр Selinux на disabled.

Для дальнейшей настройки FreeIPA нам потребуется, чтобы DNS-сервер хранил запись о нашем LDAP-сервере. В рамках данной лабораторной работы мы не будем настраивать отдельный DNS-сервер и просто добавим запись в файл /etc/hosts:
```
192.168.56.10 ipa.otus.lan ipa
```
Установим модуль DL1:
```console
[root@ipa ~]# yum install -y @idm:DL1
```
Установим FreeIPA-сервер:
```console
[root@ipa ~]# yum install -y ipa-server
```
Запустим скрипт установки:
```console
[root@ipa ~]# ipa-server-install
```
Далее, нам потребуется указать параметры нашего LDAP-сервера, после ввода каждого параметра нажимаем Enter, если нас устраивает параметр, указанный в квадратных скобках, то можно сразу нажимать Enter:
```
Do you want to configure integrated DNS (BIND)? [no]: no
Server host name [ipa.otus.lan]: <Нажимаем Enter>
Please confirm the domain name [otus.lan]: <Нажимем Enter>
Please provide a realm name [OTUS.LAN]: <Нажимаем Enter>
Directory Manager password: <Указываем пароль минимум 8 символов>
Password (confirm): <Дублируем указанный пароль>
IPA admin password: <Указываем пароль минимум 8 символов>
Password (confirm): <Дублируем указанный пароль>
NetBIOS domain name [OTUS]: <Нажимаем Enter>
Do you want to configure chrony with NTP server or pool address? [no]: no
The IPA Master Server will be configured with:
Hostname:       ipa.otus.lan
IP address(es): 192.168.56.10
Domain name:    otus.lan
Realm name:     OTUS.LAN

The CA will be configured with:
Subject DN:   CN=Certificate Authority,O=OTUS.LAN
Subject base: O=OTUS.LAN
Chaining:     self-signed
Проверяем параметры, если всё устраивает, то нажимаем yes
Continue to configure the system with these values? [no]: yes
```

Если получаем ошибку `Pv6 stack is enabled in the kernel but there is no interface that has ::1 address assigned.`, нужно активировать ipv6 на lo0 интерфейсе:
```console
[root@ipa ~]# vim /etc/sysctl.conf
net.ipv6.conf.lo.disable_ipv6 = 0
[root@ipa ~]# sysctl -p
```
Далее начнется процесс установки. Процесс установки занимает примерно 5 минут (иногда время может быть другим). Если мастер успешно выполнит настройку FreeIPA то в конце мы получим сообщение: 
The ipa-server-install command was successful.

При вводе параметров установки мы вводили 2 пароля:
- Directory Manager password — это пароль администратора сервера каталогов, У этого пользователя есть полный доступ к каталогу.
- IPA admin password — пароль от пользователя FreeIPA admin

После успешной установки FreeIPA, проверим, что сервер Kerberos может выдать нам билет:
```console
[root@ipa ~]# kinit admin
Password for admin@OTUS.LAN:

[root@ipa ~]# klist
Ticket cache: KCM:0
Default principal: admin@OTUS.LAN

Valid starting     Expires            Service principal
08/19/24 19:03:34  08/20/24 18:21:59  krbtgt/OTUS.LAN@OTUS.LAN
```
Для удаление полученного билета:
```console
[root@ipa ~]# kdestroy
[root@ipa ~]# klist
klist: Credentials cache 'KCM:0' not found
```
Мы можем зайти в Web-интерфейс нашего FreeIPA-сервера, для этого на нашей хостой машине нужно прописать следующую строку в файле Hosts `192.168.56.10 ipa.otus.lan`

__Конфигурация клиентов__

Настройка клиента похожа на настройку сервера. На хосте также нужно:
- Настроить синхронизацию времени и часовой пояс
- Настроить (или отключить) firewall
- Настроить (или отключить) SElinux
- В файле hosts должна быть указана запись с FreeIPA-сервером и хостом

Хостов, которые требуется добавить к серверу может быть много, для упрощения нашей работы настройки будут выполняться с помощью Ansible. 

__Проверка работы LDAP__

На сервере FreeIPA создадим пользователя и попробуем залогиниться клиенту. 

Авторизируемся на сервере:
```console
[root@ipa ~]# kinit admin
```
Создадим пользователя otus-user:
```console
[root@ipa ~]# ipa user-add otus-user --first=Otus --last=User --password
Password: 
Enter Password again to verify: 
----------------------
Added user "otus-user"
----------------------
  User login: otus-user
  First name: Otus
  Last name: User
  Full name: Otus User
  Display name: Otus User
  Initials: OU
  Home directory: /home/otus-user
  GECOS: Otus User
  Login shell: /bin/sh
  Principal name: otus-user@OTUS.LAN
  Principal alias: otus-user@OTUS.LAN
  User password expiration: 20240819174432Z
  Email address: otus-user@otus.lan
  UID: 868000003
  GID: 868000003
  Password: True
  Member of groups: ipausers
  Kerberos keys available: True
```
На хосте client1 или client2 выполним команду:
```console
[root@client1 ~]# kinit otus-user
Password for otus-user@OTUS.LAN: 
Password expired.  You must change it now.
Enter new password: 
Enter it again: 
[root@client1 ~]#
```
Система запросит у нас пароль и попросит ввести новый пароль. 

На этом процесс добавления хостов к FreeIPA-серверу завершен.
