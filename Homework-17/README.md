## OTUS Linux Professional - Урок 25. Основы сбора и хранения логов.

#### Цель домашнего задания

Научится проектировать централизованный сбор логов. Рассмотреть особенности разных платформ для сбора логов

#### Описание домашнего задания
1. В Vagrant разворачиваем 2 виртуальные машины web и log
2. На web настраиваем nginx  
3. На log настраиваем центральный лог сервер на любой системе на выбор
  - journald;
  - rsyslog;
  - elk.
4. Настраиваем аудит, следящий за изменением конфигов nginx 

Все критичные логи с web должны собираться и локально и удаленно.
Все логи с nginx должны уходить на удаленный сервер (локально только критичные).
Логи аудита должны также уходить на удаленную систему.

#### Инструкция по выполнению
1. Создаем виртуальные машины
```console
$ vagrant up
```
2. Заходим на web-сервер
```console
$ vagrant ssh web
$ sudo -i
```
3. Для правильной работы c логами, нужно, чтобы на всех хостах было настроено одинаковое время. Проверяем:
```console
root@web:~# timedatectl
               Local time: Tue 2024-06-25 17:26:32 UTC
           Universal time: Tue 2024-06-25 17:26:32 UTC
                 RTC time: Tue 2024-06-25 17:26:32
                Time zone: Etc/UTC (UTC, +0000)
System clock synchronized: no
              NTP service: inactive
          RTC in local TZ: no
```
Видим что NTP неактивно. Настраиваем синхронизацию времени.
Синхронизацию времени можно настроить с помощью ntpd, chrony и systemd-timesyncd. Первый считается устаревшим, второй используется в более сложных схемах чем простая синхронизация времени с удаленным ntp сервером. Поэтому будем настраивать systemd-timesyncd. 

Вносим в /etc/systemd/timesyncd.conf список серверов, с которыми будем синхронизироваться:
```
[Time]
NTP=0.ru.pool.ntp.org, 1.ru.pool.ntp.org 2.ru.pool.ntp.org 3.ru.pool.ntp.org
...
...
```
Включаем синхронизацию:
```console
root@web:~# timedatectl set-ntp true
```
После выполнения данной команды должна запуститься служба systemd-timesyncd:
```console
root@web:~# systemctl status systemd-timesyncd
● systemd-timesyncd.service - Network Time Synchronization
     Loaded: loaded (/lib/systemd/system/systemd-timesyncd.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2024-06-25 17:46:14 UTC; 36s ago
       Docs: man:systemd-timesyncd.service(8)
   Main PID: 3186 (systemd-timesyn)
     Status: "Initial synchronization to time server 91.206.16.3:123 (1.ru.pool.ntp.org)."
      Tasks: 2 (limit: 1586)
     Memory: 1.3M
        CPU: 31ms
     CGroup: /system.slice/systemd-timesyncd.service
             └─3186 /lib/systemd/systemd-timesyncd

Jun 25 17:46:14 web systemd[1]: Starting Network Time Synchronization...
Jun 25 17:46:14 web systemd[1]: Started Network Time Synchronization.
Jun 25 17:46:24 web systemd-timesyncd[3186]: Timed out waiting for reply from 91.207.136.55:123 (1.ru.pool.ntp.org).
Jun 25 17:46:25 web systemd-timesyncd[3186]: Initial synchronization to time server 91.206.16.3:123 (1.ru.pool.ntp.org).
```
Проверить статус синхронизации:
```console
root@web:~# timedatectl timesync-status
       Server: 91.206.16.3 (1.ru.pool.ntp.org)
Poll interval: 1min 4s (min: 32s; max 34min 8s)
         Leap: normal
      Version: 4
      Stratum: 1
    Reference: GPS
    Precision: 1us (-24)
Root distance: 991us (max: 5s)
       Offset: -854us
        Delay: 90.875ms
       Jitter: 322us
 Packet count: 2
    Frequency: +0.000ppm

```
Меняем временную зону:
```console
root@web:~# timedatectl set-timezone Europe/Moscow
```
Проверяем дату и время.

Тоже самое проделываем на втором сервере - log.

4. Установим nginx на сервере web:
```console
root@web:~# apt update && apt install -y nginx
root@web:~# systemctl status nginx
```
5. На сервере log убеждаемся что установлен rsyslog:
```console
root@log:~# apt list rsyslog
Listing... Done
rsyslog/jammy-updates,jammy-security,now 8.2112.0-2ubuntu2.2 amd64 [installed,automatic]
```
Все настройки rsyslog хранятся в файле /etc/rsyslog.conf. Для того, чтобы наш сервер мог принимать логи, нам необходимо внести следующие изменения в файл.

Указываем rsyslog'у слушать на портах tcp/514 и udp/514. Раскомментируем строчки:
```shell
# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# provides TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")
```
В конец файла /etc/rsyslog.conf добавляем правила приёма сообщений от хостов. Данные параметры будут отправлять в папку /var/log/rsyslog логи, которые будут приходить от других серверов. Например, access-логи nginx от сервера web, будут идти в файл /var/log/rsyslog/web/nginx_access.log
```shell
#Add remote logs
$template RemoteLogs, "/var/log/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?RemoteLogs
& ~
```
Перезапускаем службу rsyslog:
```console
root@log:~# systemctl restart rsyslog
```
Проверяем что rsyslog прослушивает на портах 514:
```console
root@log:~# ss -lntup
```

6. Далее настроим отправку логов с web-сервера. Заходим на web сервер.

Находим в файле /etc/nginx/nginx.conf раздел с логами и приводим их к следующему виду:
```
...
access_log syslog:server=192.168.56.15:514,tag=nginx_access,severity=info combined;
error_log /var/log/nginx/error.log;
error_log syslog:server=192.168.56.15:514,tag=nginx_error;
...
```
Для Access-логов указываем удаленный сервер и уровень логов, которые нужно отправлять. Для error_log добавляем удаленный сервер. Если требуется чтобы логи хранились локально и отправлялись на удаленный сервер, требуется указать 2 строки. 	
Tag нужен для того, чтобы логи записывались в разные файлы.
По умолчанию, error-логи отправляют логи, которые имеют severity: error, crit, alert и emerg. Если требуется хранить или пересылать логи с другим severity, то это также можно указать в настройках nginx. 

Перезапускаем nginx: 
```console
root@web:~# systemctl restart nginx
```
Попробуем несколько раз зайти по адресу http://192.168.56.10
Далее заходим на log-сервер и смотрим информацию об nginx.

Поскольку наше приложение работает без ошибок, файл nginx_error.log не будет создан. Чтобы сгенерировать ошибку, можно переместить файл веб-страницы, который открывает nginx:
```console
root@web:~# mv /var/www/html/index.nginx-debian.html /var/www/
```
После этого мы получим 403 ошибку.

Проверяем еще раз логи.

7. Создадим еще одну виртуальную машину "third" и перенаправим все логи с неё на rsyslog серевер "log".

На виртуальной машине "third" добавляем следующие строки в файл конфигурации /etc/rsyslog.conf:
```shell
# Send everything to log server
#
*.* @@192.168.56.15:514
```
Перезагружаем rsyslog:
```console
root@third:~# systemctl restart rsyslog
```
Заходим на log сервер и убеждаемся в наличии логов с клиента "third".
