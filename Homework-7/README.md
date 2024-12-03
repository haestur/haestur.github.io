## OTUS Linux Professional - Урок 9. NFS, FUSE.

#### ЦЕЛЬ ДЗ:
1. `vagrant up` должен поднимать 2 настроенных виртуальных машины (сервер NFS и клиента) без дополнительных ручных действий
2.  На сервере NFS должна быть подготовлена и экспортирована директория
3.  В экспортированной директории должна быть поддиректория с именем __upload__ с правами на запись в неё
4.  Экспортированная директория должна автоматически монтироваться на клиенте при старте виртуальной машины (systemd, autofs или fstab -  любым способом)
5.  Монтирование и работа NFS на клиенте должна быть организована с использованием NFSv3 по протоколу UDP
6.  firewall должен быть включен и настроен как на клиенте, так и на сервере
7.  * настроить аутентификацию через KERBEROS с использованием NFSv4

>[!TIP]
>При создании виртуальных машин с помощью текущего __Vagrantfile__, на сервере запускается скрипт __nfss_script.sh__, а на клиенте - __nfsс_script.sh__. Данные скрипты выполняют действия описаные ниже, то есть настраивают nfs сервер и nfs клиент.

#### ПОРЯДОК ВЫПОЛНЕНИЯ:
1. Поднимаем с помощью Vagrantfile две виртуальные машины: __nfss__ - сервер NFS, __nfsc__ - клиент NFS
   
2. Настраиваем NFS сервер
   
Устанавливаем утилиты для отладки NFS:
```
[root@nfss ~]# yum install nfs-utils
```
Включаем фаервол:
```
[root@nfss ~]# systemctl enable firewalld --now
```
Разрешаем в firewall доступ к сервисам NFS:
```
[root@nfss ~]# firewall-cmd --add-service="nfs3" --add-service="rpc-bind" --add-service="mountd" --permanent
[root@nfss ~]# firewall-cmd --reload
```
Запускаем сервер NFS:
```
[root@nfss ~]# systemctl enable nfs --now
```
>[!NOTE]
>В CentOS7 для конфигурации NFSv3 over UDP он не требует дополнительной настройки. С параметрами по умолчанию можно ознакомится в файле __/etc/nfs.conf__

Проверяем наличие слушаемых портов 2049/udp, 2049/tcp, 20048/udp,  20048/tcp, 111/udp, 111/tcp
```
[root@nfss ~]# ss -lntup
```
Создаем и настриваем директорию, которую будем расшаривать:
```
[root@nfss ~]# mkdir -p /srv/share/upload
[root@nfss ~]# chown -R nfsnobody:nfsnobody /srv/share
[root@nfss ~]# chmod 0777 /srv/share/upload
```
Добавляем запись в /etc/exports:
```
[root@nfss ~]# cat << EOF > /etc/exports
> /srv/share 192.168.50.11/32(rw,sync,root_squash)
> EOF
```
Экспортируем только что созданную директорию:
```
[root@nfss ~]# exportfs -r
```
Проверяем:
```
[root@nfss ~]# exportfs -s
/srv/share  192.168.50.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```
3. Настраиваем клиент NFSC
Устанавливаем утилиты для отладки NFS:
```
[root@nfss ~]# yum install nfs-utils
```
Включаем фаервол:
```
[root@nfss ~]# systemctl enable firewalld --now
```
Добавляем в __/etc/fstab__ строку:
```
[root@nfsc ~]# echo "192.168.50.10:/srv/share/ /mnt nfs vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab
```
Выполняем:
```
[root@nfsc ~]# systemctl daemon-reload
[root@nfsc ~]# systemctl restart remote-fs.target
```
>[!NOTE]
>Перечитывать конфигурацию systemd нужно потому что systemd обрабатывает файл fstab, чтобы создать модули для монтирования устройств. Такие модули находятся во временной папке /run.
>В данном случае происходит автоматическая генерация systemd units в каталоге `/run/systemd/generator/`, которые производят монтирование при первом обращении к каталогу `/mnt/`

Заходим в директорию `/mnt/` и проверяем успешность монтирования
```
[root@nfsc mnt]# mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=30,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=10737)
192.168.50.10:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.50.10,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.50.10)
```
Посмотреть на сервере кем промонтированны шары:
```
[root@nfss ~]# showmount -a
```
