## OTUS Linux Professional - Урок 6. Файловые системы и LVM - 1.

#### ЦЕЛЬ: НАУЧИТЬСЯ РАБОТАТЬ С LVM

#### ЗАДАЧИ:
1. Уменьшить том / до 8GB
2. Выделить том под /var в зеркало
3. Выделить том под /home
4. Создать снапшот тома /home, восстановить удалённые файлы со снапшота

#### ПРОЦЕСС ВЫПОЛНЕНИЯ:

#### ЗАДАНИЕ 1. Уменьшить том / до 8GB

Эту часть можно выполнить разными способами, в данном примере мы будем уменьшать / до 8G без использования LiveCD. Если вы оставили том /dev/sdb из прошлых примеров заполненным, очистите его (или создайте чистый стенд). Перед началом работы поставьте пакет xfsdump - он будет необходим для снятия копии / тома.
Подготовим временный том для / раздела:
```
[root@lvm ~]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.

[root@lvm ~]# vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created

[root@lvm ~]# lvcreate -n lv_root -l +100%FREE /dev/vg_root
WARNING: ext4 signature detected on /dev/vg_root/lv_root at offset 1080. Wipe it? [y/n]: y
  Wiping ext4 signature on /dev/vg_root/lv_root.
  Logical volume "lv_root" created.
```
Создадим на нем файловую систему и смонтируем его, чтобы перенести туда данные:
```
[root@lvm ~]# mkfs.xfs /dev/vg_root/lv_root
meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=655104 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2620416, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

[root@lvm ~]# mount /dev/vg_root/lv_root /mnt
```
Этой командой копируем все данные с / раздела в /mnt:
```
[root@lvm ~]# yum install xfsdump

[root@lvm ~]# xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
…
xfsrestore: Restore Status: SUCCESS
```
Тут вывод большой, но в итоге вы должны увидеть SUCCESS. Проверить что скопировалось можно командой ls /mnt.

Затем сконфигурируем grub для того, чтобы при старте перейти в новый /.
Сымитируем текущий root, сделаем в него chroot и обновим grub:
```
[root@lvm ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; \
 do mount --bind $i /mnt/$i; done

[root@lvm ~]# chroot /mnt/

[root@lvm /]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-1160.102.1.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1160.102.1.el7.x86_64.img
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
```
Обновим образ initrd. Что это такое и зачем нужно вы узнаете из следующей лекции.
```
[root@lvm /]# cd /boot ; for i in `ls initramfs-*img`; \
do dracut -v $i `echo $i|sed "s/initramfs-//g; \
> s/.img//g"` --force; done
```
Ну и для того, чтобы при загрузке был смонтирован нужны root нужно в файле
/boot/grub2/grub.cfg заменить rd.lvm.lv=VolGroup00/LogVol00 на rd.lvm.lv=vg_root/lv_root
```
[root@lvm ~]# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  
  └─VolGroup00-LogVol01 253:2    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
└─vg_root-lv_root       253:1    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
├─vg0-mirror_rmeta_0    253:3    0    4M  0 lvm  
│ └─vg0-mirror          253:7    0  816M  0 lvm  
└─vg0-mirror_rimage_0   253:4    0  816M  0 lvm  
  └─vg0-mirror          253:7    0  816M  0 lvm  
sde                       8:64   0    1G  0 disk 
├─vg0-mirror_rmeta_1    253:5    0    4M  0 lvm  
│ └─vg0-mirror          253:7    0  816M  0 lvm  
└─vg0-mirror_rimage_1   253:6    0  816M  0 lvm  
  └─vg0-mirror          253:7    0  816M  0 lvm  
```
Теперь нам нужно изменить размер старой VG и вернуть на него рут. Для этого удаляем старый LV размером в 40G и создаём новый на 8G:
```
[root@lvm ~]# lvremove /dev/VolGroup00/LogVol00
Do you really want to remove active logical volume VolGroup00/LogVol00? [y/n]: y
  Logical volume "LogVol00" successfully removed

[root@lvm ~]# lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
WARNING: xfs signature detected on /dev/VolGroup00/LogVol00 at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/VolGroup00/LogVol00.
  Logical volume "LogVol00" created.
```
Проделываем на нем те же операции, что и в первый раз:
```
[root@lvm ~]# mkfs.xfs /dev/VolGroup00/LogVol00

[root@lvm ~]# mount /dev/VolGroup00/LogVol00 /mnt

[root@lvm ~]# xfsdump -J - /dev/vg_root/lv_root | \
 xfsrestore -J - /mnt
xfsrestore: using file dump (drive_simple) strategy
…
xfsrestore: Restore Status: SUCCESS
```
Так же как в первый раз cконфигурируем grub, за исключением правки /etc/grub2/grub.cfg
```
[root@lvm ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; \
 do mount --bind $i /mnt/$i; done
[root@lvm ~]# chroot /mnt/
[root@lvm /]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-1160.102.1.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1160.102.1.el7.x86_64.img
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done

[root@lvm /]# cd /boot ; for i in `ls initramfs-*img`; \
 do dracut -v $i `echo $i|sed "s/initramfs-//g; \
> s/.img//g"` --force; done
Executing: /sbin/dracut -v initramfs-3.10.0-1160.102.1.el7.x86_64.img 3.10.0-1160.102.1.el7.x86_64 --force
…
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```
Пока не перезагружаемся и не выходим из под chroot - мы можем заодно перенести /var.

#### ЗАДАНИЕ 2. Выделить том под /var в зеркало

Выделить том под /var в зеркало
На свободных дисках создаем зеркало:
```
[root@lvm boot]# pvcreate /dev/sdc /dev/sdd
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.

[root@lvm boot]# vgcreate vg_var /dev/sdc /dev/sdd
  Volume group "vg_var" successfully created

[root@lvm boot]# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.
```
Создаем на нем ФС и перемещаем туда /var:
```
[root@lvm boot]# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.42.9 (28-Dec-2013)
Writing superblocks and filesystem accounting information: done

[root@lvm boot]# mount /dev/vg_var/lv_var /mnt
[root@lvm boot]# cp -aR /var/* /mnt/
```
На всякий случай сохраняем содержимое старого var (или же можно его просто удалить):
```
[root@lvm boot]# mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
```
Ну и монтируем новый var в каталог /var:
```
[root@lvm boot]# umount /mnt
[root@lvm boot]# mount /dev/vg_var/lv_var /var
```
Правим fstab для автоматического монтирования /var:
```
[root@lvm boot]# echo "`blkid | grep var: | awk '{print $2}'` \
 /var ext4 defaults 0 0" >> /etc/fstab
```
После чего можно успешно перезагружаться в новый (уменьшенный root) и удалять
временную Volume Group:
```
[root@lvm ~]# lvremove /dev/vg_root/lv_root
Do you really want to remove active logical volume vg_root/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed

[root@lvm ~]# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed

[root@lvm ~]# pvremove /dev/sdb
  Labels on physical volume "/dev/sdb" successfully wiped.
```
#### ЗАДАНИЕ 3. Выделить том под /home

Выделяем том под /home по тому же принципу что делали для /var:
```
[root@lvm ~]# lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
  Logical volume "LogVol_Home" created.

[root@lvm ~]# mkfs.xfs /dev/VolGroup00/LogVol_Home
[root@lvm ~]# mount /dev/VolGroup00/LogVol_Home /mnt/
[root@lvm ~]# cp -aR /home/* /mnt/
[root@lvm ~]# rm -rf /home/*
[root@lvm ~]# umount /mnt
[root@lvm ~]# mount /dev/VolGroup00/LogVol_Home /home/
```
Правим fstab для автоматического монтирования /home:
```
[root@lvm ~]# echo "`blkid | grep Home | awk '{print $2}'` \
 /home xfs defaults 0 0" >> /etc/fstab
```
#### ЗАДАНИЕ 4. Создать снапшот тома /home, восстановить удалённые файлы со снапшота

Генерируем файлы в /home/:
```
[root@lvm ~]# touch /home/file{1..20}
```
Снять снапшот:
```
[root@lvm ~]# lvcreate -L 100MB -s -n home_snap \
 dev/VolGroup00/LogVol_Home
```
Удалить часть файлов:
```
[root@lvm ~]# rm -f /home/file{11..20}
```
Процесс восстановления из снапшота:
```
[root@lvm ~]# umount /home
[root@lvm ~]# lvconvert --merge /dev/VolGroup00/home_snap
  Merging of volume VolGroup00/home_snap started.
  VolGroup00/LogVol_Home: Merged: 100.00%
[root@lvm ~]# mount /home
[root@lvm ~]# ls -al /home
total 0
drwxr-xr-x.  3 root    root    292 Dec 14 09:51 .
drwxr-xr-x. 20 root    root    268 Dec 14 09:31 ..
-rw-r--r--.  1 root    root      0 Dec 14 09:51 file1
-rw-r--r--.  1 root    root      0 Dec 14 09:51 file10
-rw-r--r--.  1 root    root      0 Dec 14 09:51 file11
…
```  
