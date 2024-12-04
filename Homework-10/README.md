## OTUS Linux Professional - Урок 12. Инициализация системы. Systemd.

#### ЦЕЛЬ:
1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig или в /etc/default).
2. Установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).
3. Дополнить unit-файл httpd (он же apache2) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.

>[!TIP]
>В текущем репозитории все описанные ниже задачи выполняются автоматически при выполнении команды `vagrant up`. Во время выполнения этой команды:
> - поднимается виртуальная машина с CentOS 8 Stream
> - запускается ansible-playbook auto_configuration.yaml (файл inventory создается вагрантом автоматически и помещается в _.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory_, см. [The Inventory File](https://developer.hashicorp.com/vagrant/docs/provisioning/ansible_intro#the-inventory-file)

#### ЗАДАНИЕ 1:
1.  Создаём файл с конфигурацией для сервиса в директории /etc/sysconfig - из неё сервис будет брать необходимые переменные
```
[root@nginx ~#] cat /etc/sysconfig/watchlog
# Configuration file for my watchlog service
# Place it to /etc/sysconfig

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
```
2. Cоздаем /var/log/watchlog.log и пишем туда строки на своё усмотрение и ключевое слово "ALERT"
```
[root@packages ~]# cat /var/log/watchlog.log
[INFO] Apr 21 07:40:01 packages systemd[1]: sysstat-collect.service: Succeeded.
[INFO] Apr 21 07:40:01 packages systemd[1]: Started system activity accounting tool.
[INFO] Apr 21 07:50:01 packages systemd[1]: Starting system activity accounting tool...
[INFO] Apr 21 07:50:01 packages systemd[1]: sysstat-collect.service: Succeeded.
[INFO] Apr 21 07:50:01 packages systemd[1]: Started system activity accounting tool.
[INFO] Apr 21 08:00:00 packages systemd[1]: Starting system activity accounting tool...
[INFO] Apr 21 08:00:00 packages systemd[1]: Started Update a database for mlocate.
[ALERT] Apr 21 08:00:00 packages systemd[1]: sysstat-collect.service: fail.
[INFO] Apr 21 08:00:00 packages systemd[1]: Started system activity accounting tool.
[INFO] Apr 21 08:00:01 packages systemd[1]: mlocate-updatedb.service: Succeeded.
[INFO] Apr 21 08:08:20 packages systemd[1]: Starting dnf makecache...
[INFO] Apr 21 08:08:20 packages dnf[10468]: Metadata cache refreshed recently.
[INFO] Apr 21 08:08:20 packages systemd[1]: dnf-makecache.service: Succeeded.
[INFO] Apr 21 08:08:20 packages systemd[1]: Started dnf makecache.
[INFO] Apr 21 08:09:26 packages su[10475]: (to root) vagrant on pts/0
[INFO] Apr 21 08:10:01 packages systemd[1]: Starting system activity accounting tool...
[ALERT] Apr 21 08:10:01 packages systemd[1]: sysstat-collect.service: fail.
[INFO] Apr 21 08:10:01 packages systemd[1]: Started system activity accounting tool.
```
3. Создаем скрипт, который будет отправлять лог в системный журнал когда найдет в нашем логе слово "ALERT":
```
[root@packages ~]# cat /opt/watchlog.sh
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null; then
    logger "$DATE: I found word, Master!"
else
    exit 0
fi
```
```
[root@packages ~]# chmod +x /opt/watchlog.sh
```
4. Создаем юнит для сервиса:
```
[root@packages ~]# cat /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```
5. Создаем юнит для таймера:
```
[root@packages ~]# cat /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
OnActiveSec=5
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
```
>[!NOTE]
>Если указать просто `OnUnitActiveSec=30`, то таймер не начнет выполняться пока не будет каким-то образом запущен сервис. Потому что OnUnitActiveSec определяет таймер относительно времени, когда последний раз был запущен сервис, на который ссылается этот таймер. Поэтому нужно как-то запустить один раз этот сервис, например, вручную. Также для периодических выполнений заданий можно использовать OnCalendar, вместо OnUnitActiveSec.

6. Стартуем таймер:
```
[root@nginx ~#] systemctl start watchlog.timer
```
7. Проверяем что всё работает как ожидалось:
```
[root@packages ~]# tail -f /var/log/messages
Apr 21 17:44:20 packages systemd[1]: watchlog.service: Succeeded.
Apr 21 17:44:20 packages systemd[1]: Started My watchlog service.
Apr 21 17:45:00 packages systemd[1]: Starting My watchlog service...
Apr 21 17:45:00 packages root[11482]: Sun Apr 21 17:45:00 UTC 2024: I found word, Master!
Apr 21 17:45:00 packages systemd[1]: watchlog.service: Succeeded.
Apr 21 17:45:00 packages systemd[1]: Started My watchlog service.
Apr 21 17:45:30 packages systemd[1]: Starting My watchlog service...
Apr 21 17:45:30 packages root[11500]: Sun Apr 21 17:45:30 UTC 2024: I found word, Master!
```

#### ЗАДАНИЕ 2. Установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi)

1. Устанавливаем spawn-fcgi и необходимые для него пакеты:
```
[root@packages ~]# yum install epel-release -y && yum install spawn-fcgi php php-cli
```
`/etc/rc.d/init.d/spawn-fcgi` - cам Init скрипт, который будем переписывать

2. Раскомментируем строки с переменными в /etc/sysconfig/spawn-fcgi:
```
[root@packages ~]# cat /etc/sysconfig/spawn-fcgi
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"
```
3. Создаем юнит сервис для spawn-fcgi:
```
[root@packages ~]# cat /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
```
4. Проверяем что всё работает как ожидалось:
```
[root@packages ~]# systemctl start spawn-fcgi.service 
[root@packages ~]# systemctl status spawn-fcgi.service 
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2024-04-21 18:00:09 UTC; 6s ago
 Main PID: 36957 (php-cgi)
    Tasks: 33 (limit: 100628)
   Memory: 18.8M
   CGroup: /system.slice/spawn-fcgi.service
           ├─36957 /usr/bin/php-cgi
           ├─36958 /usr/bin/php-cgi
           ├─36959 /usr/bin/php-cgi
           ├─36960 /usr/bin/php-cgi
           ├─36961 /usr/bin/php-cgi
           ├─36962 /usr/bin/php-cgi
          ...
          ...
Apr 21 18:00:09 packages systemd[1]: Started Spawn-fcgi startup service by Otus.
```
#### ЗАДАНИЕ 3. Дополнить unit-файл httpd (он же apache2) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.

1. Для запуска нескольких экземпляров сервиса будем использовать шаблон в конфигурации файла окружения /usr/lib/systemd/system/httpd.service:
```
[root@packages ~]# cat /usr/lib/systemd/system/httpd.service

[Unit]
Description=The Apache HTTP Server
Wants=httpd-init.service
After=network.target remote-fs.target nss-lookup.target httpd-init.service
Documentation=man:httpd.service(8)

[Service]
Type=notify
Environment=LANG=C

ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
# Send SIGWINCH for graceful stop
KillSignal=SIGWINCH
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target

```
2. Создаем два файла окружения, в которых задаем опции для запуска веб-серверов с необходимыми конфигурационными файлами:
```
[root@packages ~]# cat /etc/sysconfig/httpd-first 
OPTIONS=-f conf/first.conf
[root@packages ~]# cat /etc/sysconfig/httpd-second 
OPTIONS=-f conf/second.conf
```
3. В каталоге /etc/httpd/conf создаем два конфигурационных файла first.conf и second.conf. В эих файлах указываем уникальные для каждого экземпляра Listen и PidFile. В первом оставляем как в оригинальном httpd.conf, второй редактируем:
```
[root@packages ~]# cat /etc/httpd/conf/second.conf

Listen 8080
PidFile /var/run/httpd-second.pid
```
4. Запускаем оба экземпляра веб-сервера:
```
[root@packages ~]# systemctl start httpd@first
[root@packages ~]# systemctl start httpd@second
[root@packages ~]# systemctl status httpd@first
● httpd@first.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2024-04-21 18:20:12 UTC; 12s ago
...
...

[root@packages ~]# systemctl status httpd@second
● httpd@second.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2024-04-21 18:20:18 UTC; 13s ago
...
...

[root@packages ~]# ss -lntup | grep httpd
tcp   LISTEN 0      511                *:8080            *:*    users:(("httpd",pid=37450,fd=4),("httpd",pid=37449,fd=4),("httpd",pid=37448,fd=4),("httpd",pid=37446,fd=4))
tcp   LISTEN 0      511                *:80              *:*    users:(("httpd",pid=37227,fd=4),("httpd",pid=37226,fd=4),("httpd",pid=37225,fd=4),("httpd",pid=37223,fd=4))
```
