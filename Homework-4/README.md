## OTUS Linux Professional - Урок 5. Дисковая подсистема.

#### ЦЕЛЬ: НАСТРОИТЬ ПРОГРАММНЫЙ RAID С ИСПОЛЬЗОВАНИЕМ MDADM

#### ЧТО НУЖНО СДЕЛАТЬ:
- рабочий Vagrantfile с доп. дисками
- собрать RAID0/5/10 на выбор
- сломать/починить собранный RAID
- прописать собранный RAID в mdadm.conf чтобы он нормально собирался при загрузке
- создать GPT и 5 разделов

#### УСЛОВИЯ ВЫПОЛНЕНИЯ:
- есть готовый Vagrantfile
- есть скрипт для создания RAID (raid10_autosetup.bash)
- в поднятой виртуальной машине есть mdadm.conf для сборки RAID при загрузке
- \* есть Vagrantfile, который сразу собирает систему с подключенным рейдом, смонтированными разделами, и заполненным mdadm.conf
- ** перенести работающую систему с одним диском на RAID1. Даунтайм на загрузку с нового диска предпологается

#### ПОРЯДОК ДЕЙСТВИЙ:

**1.** Поднимаем виртуальную машину, к ней подключаем 6 дополнительных дисков

**2.** Проверяем что диски присутствуют:

`# lsblk`

**3.** На всякий случай зануляем супер-блоки. Иначе если диски уже были в RAID и информация о рейде осталась в супер-блоке, возникнет ошибка:

`# mdadm --zero-superblock --force /dev/sd{b,c,d,e,f,g}`

**4.** Создаем RAID10:

`# mdadm --create --verbose /dev/md0 -l 10 -n 6 /dev/sd{b,c,d,e,f,g}`

**5.** Проверяем:

`# cat /proc/mdstat`

`# mdadm --detail /dev/md0 `

В случае с RAID10 мы увидим в выводе следующее:
```
...

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde
       4       8       80        4      active sync set-A   /dev/sdf
       5       8       96        5      active sync set-B   /dev/sdg
...
```
Здесь стоит обратить внимание на set-A и set-B. Может показаться что был создан RAID0 c двумя RAID1, в которых по 3 диска. На самом деле set-A и set-B это
просто пометка дисков "правый/левый" в паре. То есть в случае RAID10 c 6 дисками мы имеем RAID 0 с тремя RAID1 (в каждом RAID1 по два диска). 
Обычно пары создаются из подряд идучих дисков. Например, /dev/sdb + /dev/sdc, /dev/sdd + /dev/sde и т.д. Но это не точно. Чтобы удостоверится в этом, можно взять одинаковые части 
данных с каждого диска и сравнить их md5sum (см. https://forums.servethehome.com/index.php?threads/mdadm-raid10-geometry.23175/):
```
# for drive in sd{a,b,d,e,f,g}; do echo ${drive}1 && dd if=/dev/${drive}1 skip=1M bs=1M count=64 2>/dev/null|md5sum; done

sda1
5r07939prq6727r468r1o9803s0079rn  -
sdb1
q806350soqr7roqps19noq5s10q87qp6  -
sdd1
q806350soqr7roqps19noq5s10q87qp6  -
sde1
5r07939prq6727r468r1o9803s0079rn  -
sdf1
rono6r3r3485nr4n17oqp331r054r304  -
sdg1
rono6r3r3485nr4n17oqp331r054r304  -
```
**6.** Создаем конф.файл `mdadm.conf`. На самом деле `mdadm.conf` не обязателен. Mdadm при загрузке сам считывает суперблоки с дисков, и определяет какой из них в каком рейде находится. 
> - mdadm.conf isnt required anymore for raid assembly. mdadm --scan does the job automagically via raid superblocks
> - When your RAID is correctly configured, the md driver is able to get everything it needs off the superblocks in the RAID components themselves. 
> The mdadm.conf file is really just there to help guide it along when there might be some ambiguity."
> See the "Auto Assembly" section of the mdadm manpage for details
> However, if you are running the md monitoring service, the mdadm.conf is where your email and event-handler details are kept.
> https://forums.whirlpool.net.au/archive/1447155

Но в некоторых случаях это сработает неправильно. Поэтому лучше сохранить конфигурацию. 

`# echo "DEVICE partitions" > /etc/mdadm/mdadm.conf` - указывает сканировать все диски на наличие информации о рейде. Эта строка не обязательна, потому что по дефолту так и есть.

Следующая команда, указанная в методичке: 

`# mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf`

Она убирает из вывода информацию о дисках. Видимо из-за того наименование дисков может поменятся и рейд не соберётся. 

Кто-то же не убирает наименование дисков, и вроде такой способ даже указан в мане по mdadm. А вообще говорят что достаточно, и даже желаетльно, оставлять только имя и uuid, 
потому как другие параметры тоже могут менятся, например имя хоста.

В mdadm.conf также написано что нужно обновить `initramfs`. Без обновления у меня после перезагрузки слетало имя рейда на /dev/md127. Не знаю почему, нужно разбираться.
Поэтому обновляем `ininramfs` как указано в файле:

`# update-initramfs -u`

Перезагружаемся, проверяем что массив корректо собрался. 
После перезагрузки можем увидить в свойствах массива `"auto-read-only"`. Это не свидетельствует ни о какой проблеме, просто если мы не пользуемся массивом долгое время, то он переходит в такой режим. Как только мы примонтируем раздел или начнем записывать данные, он перейдет в режим `active`.

**7.** Дальше попробуем сломать/починить массив:

Переводим один из дисков в fail:

`# mdadm /dev/md0 --fail /dev/sde`

Удаляем "сломанный" диск из массива:

`# mdadm /dev/md0 --remove /dev/sde`

Представим, что мы вставили новый диск в сервер и теперь нам нужно добавить его в RAID:

`# mdadm /dev/md0 --add /dev/sde`

Диск должен пройти стадию rebuilding. Например, если это был RAID 1 (зеркало), то данные должны скопироваться на новый диск. Процесс rebuild-а можно увидеть в выводе следующих команд:
```
# cat /proc/mdstat
...
[========>............] recovery = 44.6%
...
```
```
# mdadm -D /dev/md0
...
 spare rebuilding /dev/sde
...
```
**8.** Создаем GPT разметку на массиве, пять разделов и монтируем их. 
```
# apt install parted
# parted -s /dev/md0 mklabel gpt 
```
Создаем разделы:
```
# parted /dev/md0 mkpart primary ext4 0% 20%
# parted /dev/md0 mkpart primary ext4 20% 40%
# parted /dev/md0 mkpart primary ext4 40% 60%
# parted /dev/md0 mkpart primary ext4 60% 80%
# parted /dev/md0 mkpart primary ext4 80% 100%
```

Создаем файловую систему на каждом разделе:

`# for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done`

Монтируем разделы по каталогам:
```
# mkdir -p /raid/part{1,2,3,4,5}
# for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
```