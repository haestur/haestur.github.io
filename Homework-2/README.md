## OTUS Linux Professional - Урок 2. Vagrant.

### ЗАДАНИЕ 1: ОБНОВЛЕНИЕ ЯДРА

#### ЦЕЛЬ ЗАДАНИЯ: Обновить ядро на CentOS 8

#### ПОРЯДОК ДЕЙСТВИЙ:

1. Создаем `Vagrantfile` с описанием конфигурации виртуальной машины. Используем CentOS 8 с устаревшим ядром.

2. Запускаем виртуальную машину и подключаемся к ней:
```
$ vagrant up
$ vagrant ssh
```
4. Проверяем текущую версию ядра:
```
$ uname -r
   
   4.18.0-516.el8.x86_64
```
5. Подключаем репозиторий, откуда возьмём необходимую версию ядра:
```
$ sudo yum install -y https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm 
```
6. В репозитории elrepo есть две версии ядер - **kernel-lt** и **kernel-ml**. Обе версии собраны с официальных исходников kernel.org.
Разница в том что kernel-lt основано на long-term ветке, а kernel-ml - на mainline stable. 
Устанавливаем последнюю kernel-ml версию ядра:
```
$ sudo yum --enablerepo elrepo-kernel install kernel-ml -y
```
7. В инструкции указано обновить конфигурации grub командой grub2-mkconfig. Но похоже что в CentOS8 это лишнее действие. Оно не обновляет меню загрузки,
потому как меню загрузки теперь находится в каталоге `/boot/loader/entrie`s, а не в `/boot/grub2/grub.cfg`. Этот файл с меню генерируется при установке ядра скриптом `/bin/kernel-install`.

Для управления загрузкой в RH8/CentOS8 используется `grubby`. Cмотрим, какое сейчас ядро установленно для загрузки по умолчанию:
```
sudo grubby --default-kernel
   
   /boot/vmlinuz-6.7.9-1.el8.elrepo.x86_64
```  
Видим что это наше новое ядро, поэтому никаких действий больше не требуется, переходим к шагу 7. Если нужно было бы поменять, то мы бы сначала посмотрели доступные ядра и их индексы 
командой `sudo grubby --info=ALL`, и далее установили ядро по умолчанию командой `grubby --set-default-index=entry-index`

7. Перезагружаемся и проверяем версию ядра:
```
$ uname -r 
   6.7.8-1.el8.elrepo.x86_64
```

---
### ЗАДАНИЕ 2: Сборка ядра из исходников

### ЦЕЛЬ ЗАДАНИЯ: Собрать ядро из исходников

Есть несколько способов сборки ядра. Я буду собирать ядро для CentOS "классическим" способом, хотя правильнее наверное собирать методами для конкретных дистрибутивов.

### ПОРЯДОК ДЕЙСТВИЙ:

1. Поднимаем виртуальную машину CentOS с устаревшим ядром и подключаемся к ней по ssh. Используем Vagrantfile с предыдущего задания

2. Ставим пакеты, необходимые для сборки ядра:
```
$ yum -y groupinstall "Development Tools"
$ yum -y install ncurses-devel
$ yum -y install hmaccalc zlib-devel binutils-devel elfutils-libelf-devel
$ yum -y install bc openssl-devel
```
Добавляем репозиторий PowerTools для возможности установки dwarves:
```
$ yum -y install dnf-plugins-core
$ yum config-manager --set-enabled powertools
$ yum -y install dwarves
```
3. Качаем исходники
```
$ cd /usr/src
$ wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.7.8.tar.xz
```
Извлекаем:
```
$ tar -Jxvf linux-6.7.8.tar.xz
$ ln -s linux-6.7.8 linux
$ cd linux
```
4. Кофигурируем наше будущее ядро. Это можно делать несколькими способами (make oldconfig, make menuconfig и другие можно посмотреть командой make help)
```
$ make menuconfig
```
Здесь кроме всего прочего, нужно проверить параметры "Additional X.509 keys for default system keyring" и "File name or PKCS#11 URI of module signing key" в разделе
Cryptographic API -> Certificates for signature checking. Они должны быть установлены в `certs/signing_key.pem` (у меня было `certs/rhel.pem`, из-за чего не подписывались модули). 
Это нужно для SecureBoot и подписи модулей. Подробнее здесь: https://www.mjmwired.net/kernel/Documentation/admin-guide/module-signing.rst

Либо отключаем подпись модулей и соотвественно поддержку SecureBoot, если в них нет необходимости: раздер "Enable loadable module support", параметр "Module signature verification"  
и "Automatically sign all modules"

5. Собираем ядро:
```
$ make -j8 bzImage
```
Результатом будет файл с названием bzImage в каталоге `arch/i386/linux/boot/`

параметр -j8 указывает задействовать 8 ядер процессора для сборки, иначе будет долго

6. Собираем модули ядра: 
```
$ make -j8 modules
```
Устанавливаем собранные модули (по умолчанию в каталог /lib/modules/$(KERNELRELEASE)/{extra,kernel}/)
```
$ make -j8 modules_install 
```
7. Устанавливаем ядро
```
$ make -j8 install
```
8. Проверяем что наше новое ядро установленно по умолчанию при загрузке системы:
```
sudo grubby --default-kernel
```
9. Перезагружаемся и смотрим версию ядра
```
[vagrant@kernel-update ~]$ uname -r

6.7.8
```

---
### ЗАДАНИЕ 3. VirtualBox Shared Folders

1. Включаем Shared Folders в Vagrantfile'е:
```
...

config.vm.synced_folder ".", "/vagrant"

...
```
2. Запускаем виртуалку и проверяем что Shared Folders работают (создаем тестовый файл на хостовой машине и проверяем что он доступен в виртуалке)

на хосте: `touch sh_folders_testing`

на госте: `ll /vagrant`

3. Обновляем ядро 

4. Проверяем что Shared Folders теперь не работают (каталог /vagrant пустой)

5. Траблшутим

- Смотрим `/etc/fstab`

- Пытаемся примонтировать:
```
$ mount vagrant

    sbin/mount.vboxsf: mounting failed with the error: No such device
```
- Смотрим логи `/var/log/messages`, там ошибка `"modprobe vboxguest failed". Не удается загрузить модуль vboxguest.` Видимо его нужно пересобрать под новое ядро. 

6. Пробуем сначала переустановить VirtualBox Guest Additions

- Подключаем образ VBoxGuestAdditions.iso через графическую консоль VirtualBox к нашей виртуальной машине

- Монтируем этот образ
```
$ mount -r /dev/cdrom /media
$ cd /media/
```
- запускаем установку 
```
$ ./VBoxLinuxAdditions.run
```
Ругается на заголовки ядра. Устанавливаем их
```
yum -y --enablerepo=elrepo-kernel install kernel-ml-{devel,headers} --allowerasing
```
здесь allowerasing - разрешает перезаписать заголовки старого ядра

Запускаем еще раз установку:
```
./VBoxLinuxAdditions.run
```
Видим в процессе установки - `"VirtualBox Guest Additions: Building the modules for kernel 6.7.9-1.el8.elrepo.x86_64.".` То что нам нужно. 

7. Проверяем:
```
[vagrant@kernel-update ~]$ ll /vagrant/
total 4
-rw-r--r--. 1 vagrant vagrant 576 Mar  7 09:43 Vagrantfile
-rw-rw-r--. 1 vagrant vagrant   0 Mar  7 09:43 sh_folders_testing
[vagrant@kernel-update ~]$ uname -r
6.7.9-1.el8.elrepo.x86_64
```
Видим что файлы пробрасываются, Shared Folders работает.




