## OTUS Linux Professional - Урок 27. Резервное копирование.

#### Цель: Научиться настраивать резервное копирование с помощью утилиты Borg

#### Описание домашнего задания: 
1. Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client. 2.
2. Настроить удаленный бэкап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:
- директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB;
- репозиторий для резервных копий должен быть зашифрован ключом или паролем - на усмотрение студента;
- имя бэкапа должно содержать информацию о времени снятия бекапа;
- глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;
- резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;
- написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на усмотрение студента;
- настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.

> [!CAUTION]
> В данном репозитории настройки выполняются с помощью Ansible по команде `vagrant up`. После выполнения данной команды можно сразу переходить
> к проверке (команды для проверки также указаны ниже)

#### Инструкция по выполнению домашнего задания:
1. Поднимаем виртуальные машины "backupServer" и "client":
```console
$ vagrant up
```
2. Устанавливаем Borg Backup на сервер и клиент:
```console
# apt update
# apt install borgbackup
```
3. Подготовим и примонтируем дополнительный диск для хранения бэкапов:
```console
root@backupServer:~# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
loop0    7:0    0   87M  1 loop /snap/lxd/28373
loop1    7:1    0 38.8M  1 loop /snap/snapd/21759
loop2    7:2    0 63.9M  1 loop /snap/core20/2318
sda      8:0    0   40G  0 disk 
└─sda1   8:1    0   40G  0 part /
sdb      8:16   0   10M  0 disk 
sdc      8:32   0    2G  0 disk 

```
```console
root@backupServer:~# mkfs.ext4 /dev/sdc
root@backupServer:~# echo "`blkid | grep sdc | awk '{print $2}'` /var/backup ext4 defaults 0 0" >> /etc/fstab
root@backupServer:~# mount -a
```
```console
root@backupServer:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           144M  988K  143M   1% /run
/dev/sda1        39G  1.7G   38G   5% /
tmpfs           718M     0  718M   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
vagrant         914G   86G  828G  10% /vagrant
tmpfs           144M  4.0K  144M   1% /run/user/1000
/dev/sdc        1.9G   24K  1.8G   1% /var/backup
```
4. На сервере backup создаем пользователя и каталог /var/backup. Особенностью Borg Backup является то, что он создает репозитории для хранения резервных копий в собственной домашней директории.
```console
root@backupServer:~# mkdir /var/backup
root@backupServer:~# useradd -m -d /var/backup borg
root@backupServer:~# chown borg:borg /var/backup/
```
5. Для аутентификации удаленных клиентов мы будем использовать SSH-ключи. Поэтому создадим нужную структуру папок и файлов:
```console
root@backupServer:~# su - borg
$ mkdir .ssh
$ touch .ssh/authorized_keys
$ chmod 700 .ssh
$ chmod 600 .ssh/authorized_keys
```
6. Генерируем на клиенте пару ключей:
```console
root@client:~# ssh-keygen
root@client:~# cat .ssh/id_rsa.pub
```
Вернемся на сервер и добавим открытый ключ клиента в /var/backup/.ssh/authorized_keys.
Проверяем что клиент может подключится к серверу по ssh:
```console
root@client:~# ssh borg@192.168.56.160
```
7. Настраиваем бэкап (все дальнейшие действия буду проводится на клиенте)
Инициализируем репозиторий borg на backup сервере с client сервера:
```console
root@client:~# borg init --encryption=repokey borg@192.168.56.160:my_repo
```
Запускаем для проверки создания бэкапа:
```console
root@client:~# borg create --stats --list borg@192.168.56.160:my_repo::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
```
Посмотреть информацию по бэкапам:
```console
root@client:~# borg list borg@192.168.56.160:my_repo
Enter passphrase for key ssh://borg@192.168.56.160/./my_repo: 
etc-2024-07-01_11:24:27              Mon, 2024-07-01 11:24:31 [b63f05ccfc1b8217bc18cc7287afa79b3a2bb155966c9c511fd45e1745a96efc]
```
Посмотреть список файлов в бэкапе:
```console
root@client:~# borg list borg@192.168.56.160:my_repo::etc-2024-07-01_11:24:27
```
Восстановить из резевной копии:
```console
root@client:~# borg extract borg@192.168.56.160:my_repo::etc-2024-07-01_11:24:27 etc/hostname
```
8. Автоматизируем создание бэкапов с помощью systemd. Создаем сервис и таймер в каталоге /etc/systemd/system/
```console
root@client:~# vim /etc/systemd/system/borg-backup.service

[Unit]
Description=Borg Backup

[Service]
Type=oneshot

# Парольная фраза
Environment="BORG_PASSPHRASE=1111"
# Репозиторий
Environment=REPO=borg@192.168.56.160:my_repo
# Что бэкапим
Environment=BACKUP_TARGET=/etc

# Создание бэкапа
ExecStart=/bin/borg create \
    --stats                \
    ${REPO}::etc-{now:%%Y-%%m-%%d_%%H:%%M:%%S} ${BACKUP_TARGET}

# Проверка бэкапа
ExecStart=/bin/borg check ${REPO}

# Очистка старых бэкапов
ExecStart=/bin/borg prune \
    --keep-daily  90      \
    --keep-monthly 12     \
    --keep-yearly  1       \
    ${REPO}
```
```console
root@client:~# vim /etc/systemd/system/borg-backup.timer

[Unit]
Description=Borg Backup

[Timer]
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```
Включаем и запускаем службу таймера:
```console
root@client:~# systemctl enable borg-backup.timer
Created symlink /etc/systemd/system/timers.target.wants/borg-backup.timer → /etc/systemd/system/borg-backup.timer.
root@client:~# systemctl start borg-backup.timer
root@client:~# systemctl start borg-backup.service
```
Проверяем работу таймера:
```console
root@client:~# systemctl list-timers --all
```
Логи можно посмотреть в systemd journal или в /var/log/syslog
