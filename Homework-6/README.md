## OTUS Linux Professional - Урок 8. ZFS.

#### ЦЕЛЬ:
Научится самостоятельно устанавливать ZFS, настраивать пулы, изучить основные возможности ZFS. 
#### ОПИСАНИЕ ДЗ:
1. Определить алгоритм с наилучшим сжатием:
- определить какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb, lz4)
- создать 4 файловых системы, на каждой применить свой алгоритм сжатия
- для сжатия использовать либо текстовый файл, либо группу файлов
2. Определить настройки пула.
- с помощью команды zfs import собрать pool ZFS
- Командами zfs определить настройки:
    - размер хранилища
    - тип pool
    - значение recordsize
    - какое сжатие используется
    - какая контрольная сумма используется
3. Работа со снапшотами:
- скопировать файл из удаленной директории
- восстановить файл локально. zfs receive
- найти зашифрованное сообщение в файле secret_message

#### ВЫПОЛНЕНИЕ:
Поднимаем виртуальную машину с 8 дополнительными дисками (используя Vagrantfile)
##### ЗАДАНИЕ 1. Определение алгоритма с наилучшим сжатием
1. Смотрим список всех дисков, которые есть в виртуальной машине:
```   
lsblk
```
2. Создаём 4 пула по два диска в каждом в режиме RAID 1:
```
[root@zfs ~]# zpool create otus1 mirror /dev/sda /dev/sdb
[root@zfs ~]# zpool create otus2 mirror /dev/sdc /dev/sdd
[root@zfs ~]# zpool create otus3 mirror /dev/sde /dev/sdf
[root@zfs ~]# zpool create otus4 mirror /dev/sdg /dev/sdh
```
Команды для просмотра информацию о пулах:
   
`zpool list` - показывает информацию о размере пула, количеству занятого и свободного места, дедупликации и т.д.
   
`zpool status` - показывает информацию о каждом диске, состоянии сканирования и об ошибках чтения, записи и совпадения
3. Cоздаем дополнительные датасеты в каждом пуле
> [!NOTE]
> Можно создать датасеты, либо сразу использовать весь пул (если быть точнее, то "использовать рутовый датасет", так как при создании пула создается рутовый датасет с ограниченными возможностями). Рекомендуется
> создавать дополнительные датасеты по следующим причинам:
>   - гибкость. каждый датасет можно настроить по своему, указав для датасета необходимые свойства, отличные от рутового (compression, encryption и т.п.) 
>   - это полезно для снапшотов и zfs send/recv. Вроде как нельзя на рутовый датасет реплицировать, а значит что нельзя без лишних телодвижений восстановить рутовый датасет из резервной копии:
>    And you can't replicate to it, which means you can't restore from backup to it efficiently.
>    Any attempt to zfs receive tank will fail. You can instead zfs receive tank/dataset, but if all of your applications, filesharing configs, etc all point directly to the root dataset at tank you'll have to 
>    reconfigure every last one of them to account for the difference.
>    By contrast, if you put your data--even if it is all in a single dataset!--in tank/dataset in the first place, when you screw it up later and have to restore from backup you can zfs receive tank/dataset 
>    and be done with it, no reconfiguration needed.
>
> Некоторые люди даже убирают монтирование рутового датасета, чтобы он не мешал при просмотре и чтобы не записать в него что-то случайно:
>   
> `[root@zfs ~]# zfs set mountpoint=none poolname`,  или с опцией `"-m none"` при создании пула командой `zpool create` 
> 
> Соответственно, если мы дальше создадим датасет на таком скрытом пуле, то нужно обязательно указать для него точку монтирования. Например:
> ```
> [root@zfs ~]# zfs set mountpoint=none otus1
> [root@zfs ~]# zfs set mountpoint=/mnt otus1/dataset1
> ```
Мы пока не будем заморачиваться с отмонтированным рутовым датасетом. Просто создаем дополнительные датасеты в каждом пуле:
```
[root@zfs ~]# zfs create otus1/dataset1
[root@zfs ~]# zfs create otus2/dataset2
[root@zfs ~]# zfs create otus3/dataset3
[root@zfs ~]# zfs create otus4/dataset4
```
4. Добавим разные алгоритмы сжатия на каждый датасет:
```
zfs set compression=lzjb otus1/dataset1
zfs set compression=lz4 otus2/dataset2
zfs set compression=gzip-9 otus3/dataset3
zfs set compression=zle otus4/dataset4
```
Проверим, что все датасеты имеют разные методы сжатия:
```
zfs get all | grep compression
```
> [!NOTE]
> Сжатие файлов будет работать только с файлами, которые были добавлены после включение настройки сжатия.
5. Скачаем один и тот же текстовый файл во все пулы:
```
[root@zfs ~]# for i in {1..4}; do wget -P /otus$i/dataset$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done
```
Проверим, что файл был скачан во все пулы:
```
[root@zfs ~]# ls -l /otus*/dataset*
```
Уже на этом этапе видно, что самый оптимальный метод сжатия у нас используется в датасете otus3/dataset3.
   
Проверим, сколько места занимает один и тот же файл в разных пулах и проверим степень сжатия файлов:
```
[root@zfs ~]# zfs list
NAME             USED  AVAIL     REFER  MOUNTPOINT
otus1           21.7M   330M     25.5K  /otus1
otus1/dataset1  21.6M   330M     21.6M  /otus1/dataset1
otus2           17.7M   334M     25.5K  /otus2
otus2/dataset2  17.6M   334M     17.6M  /otus2/dataset2
otus3           10.8M   341M     25.5K  /otus3
otus3/dataset3  10.7M   341M     10.7M  /otus3/dataset3
otus4           39.3M   313M     25.5K  /otus4
otus4/dataset4  39.2M   313M     39.2M  /otus4/dataset4
```
```
[root@zfs ~]# zfs get all | grep compressratio | grep -v ref
otus1           compressratio         1.82x                  -
otus1/dataset1  compressratio         1.82x                  -
otus2           compressratio         2.23x                  -
otus2/dataset2  compressratio         2.23x                  -
otus3           compressratio         3.66x                  -
otus3/dataset3  compressratio         3.67x                  -
otus4           compressratio         1.00x                  -
otus4/dataset4  compressratio         1.00x                  -

```
Видим, что алгоритм gzip-9 самый эффективный по сжатию. Но скорее всего он будет и самый медленный. Говорят что оптимальный, который "почти-налету" сжимает и почти не грузит систему - **lz4**

##### ЗАДАНИЕ 2. Определение настроек пула
1. Скачиваем архив, который содержит экспортированный пул, в домашний каталог:
```
[root@zfs ~]# wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'
```
```
tar -xzvf archive.tar.gz
```
2. Похоже что этот пул, бэкап которого мы скачали, был создан из файлов в качестве устройств пула. Так можно, но файлы в качестве компонентов пула используют только для тестирования функции zfs, потому что в таком случае мы будем зависить еще от файловой системы, на которой лежат эти файлы. 
Проверим, возможно ли импортировать к нам этот бэкап:
```
[root@zfs ~]# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
 action: The pool can be imported using its name or numeric identifier.
 config:

	otus                         ONLINE
	  mirror-0                   ONLINE
	    /root/zpoolexport/filea  ONLINE
	    /root/zpoolexport/fileb  ONLINE

```
Данный вывод показывает нам имя пула, тип raid и его состав.
Команда `zpool import` ищет устройства для импортирования. Ключ -d говорит искать в указанном каталоге. Если не указать этого, будет искать в /dev по умолчанию. 
> [!NOTE]
> Как вообще делается экспорт пула, например, если нужно перенести пул на другой сервер: выполняем команду `zpool export tank`, zfs скидывает незаписанные данные с кеша на диск, и отмонтирует пул. Дальше
> мы берем эти диски и перетыкаем в другой сервер. На новом сервере запускаем `zpool import`. ZFS начинает сканировать блочные устройства в каталоге /dev и выдает нам найденные для импортирования пулы на наших
> только что вставленных дисках. Далее выполняем импортирование пула в нашу систему как показано ниже.

3. Сделаем импорт данного пула к нам в ОС:
```
[root@zfs ~]# zpool import -d zpoolexport/ otus
[root@zfs ~]# zpool status
  pool: otus
 state: ONLINE
  scan: none requested
config:

	NAME                         STATE     READ WRITE CKSUM
	otus                         ONLINE       0     0     0
	  mirror-0                   ONLINE       0     0     0
	    /root/zpoolexport/filea  ONLINE       0     0     0
	    /root/zpoolexport/fileb  ONLINE       0     0     0
```
Посмотреть настройки импортированного пула:
```
[root@zfs ~] zpool get all otus
```
Можно также указывать конкретные параметры. Например:
```
[root@zfs ~] zfs get available otus
[root@zfs ~] zfs get readonly otus
[root@zfs ~] zfs get recordsize otus
[root@zfs ~] zfs get compression otus
[root@zfs ~] zfs get checksum otus

```
#### ЗАДАНИЕ 3. Работа со снапшотами, поиск сообщения от преподавателя

1. Скачиваем снапшот:
```
[root@zfs ~]# wget -O otus_task2.file --no-check-certificate https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download
```
2. Восстанавливаем файловую систему со снапшота:
```
[root@zfs ~]# zfs receive otus/test@today < otus_task2.file
```
>[!NOTE]
> `zfs receive` создает снапшот, содержимое которого помещается в поток, направляемый на стандартный ввод. Если получен полный поток, то также создается файловая система. В нашем случае мы получаем поток с файла
> otus_task2.file. Этот файл был создан командой `zfs send`, которая создает потоковое представление снапшота и перенаправялет его на стандартный вывод. По умолчанию, zfs send генерирует полный поток.
> В "otus/test@today" today это имя снашота

После выполения этой команды будет создан снапшот и новый датасет. Команды для просмотра списка снапшотов:
```
[root@zfs ~]# zfs list -t snapshot

[root@zfs ~]# zpool get listsnapshots otus
```

3. Ищем в каталоге /otus/test файл с именем “secret_message”:
```
[root@zfs ~]# find /otus/test -name "secret_message"
/otus/test/task1/file_mess/secret_message

[root@zfs ~]# cat /otus/test/task1/file_mess/secret_message
https://otus.ru/lessons/linux-hl/

```
Видим ссылку на курс OTUS
