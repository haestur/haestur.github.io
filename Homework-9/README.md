## OTUS Linux Professional - Урок 11. Загрузка системы.

#### ЦЕЛЬ:
1. Научиться попадать в систему без пароля
2. Устанавливать систему с LVM и переименовывать в VG
3. Добавлять модуль в initrd

#### ЗАДАНИЕ 1: Попасть в систему без пароля несколькими способами
Для получения доступа необходимо при запуске машины и при выборе ядра для загрузки нажать e - в данном контексте edit. Попадаем в окно, где мы можем изменить параметры загрузки. Далее есть несколько способов попасть в систему без пароля.

**Споcоб 1. init=/bin/sh**

В конце строки, начинающейся с _linux16_, добавляем __init=/bin/sh__ и нажимаем __сtrl-x__ для загрузки в систему. Рутовая файловая система при этом монтируется в режиме Read-Only. Если нужно перемонтировать в Read-Write:
```
[root@otuslinux ~]# mount -o remount,rw /
```
>[!NOTE]
>Параметр ядра "init" позволяет запустить указанный исполняемый файл вместо /sbin/init в качестве процесса init. То есть вместо systemd запуститься /bin/sh (и поэтому наша система останется в режиме __ro__, потому как в режим __rw__ её переводит systemd (см. заметку ниже))

**Способ 2. rd.break**

В конце строки, начинающейся с _linux16_, добавляем __rd.break__ и нажимаем __сtrl-x__ для загрузки в систему. Попадаем в emergency mode. Наша корневая файловая система смонтирована (опять же в режиме Read-Only, но мы не в ней). Далее будет пример, как попасть в нее и поменять пароль администратора:
```
[root@packages ~]# mount -o remount,rw /sysroot
[root@packages ~]# chroot /sysroot
[root@packages ~]# passwd root
[root@packages ~]# touch /.autorelabel
```
После чего можно перезагружаться и заходить в систему с новым паролем. Полезно, когда мы потеряли или вообще не имели пароля администратора.

>[!NOTE]
>__rd.break__ прерывает загрузку системы посреди выполнения initramfs/initrd, после того как короневая файловая система смонтировалась в __/sysroot__, и предоставляет нам оболочку __sh__.

**Способ 3. rw init=/sysroot/bin/sh**

В строке, начинающейся с _linux16_, заменяем __ro__ на __rw init=/sysroot/bin/sh__ и нажимаем __сtrl-x__ для загрузки в систему. В целом то же самое, что и в прошлом примере, но файловая система сразу смонтирована в режим Read-Write. В прошлых примерах тоже можно заменить __ro__ на __rw__

>[!NOTE]
>По умолчанию, в grub указано что файловая система root должна грузиться в режиме _read only_ (параметр ядра __ro__). То есть root сначала монтирутеся в режиме __ro__ и в конце загрузки системы init его перемонтируется в __rw__. Так сделано для того чтобы позволить всяким fsck проверять root-файловую систему в процессе загрузки без риска того что ядро в это время запишет туда какие-нибудь filesystem-метаданные.

#### ЗАДАНИЕ 2. Установить систему с LVM, после чего переименовать VG

1. Смотрим текущее состояние LVM:
```
[root@packages vagrant]# vgs
  VG         #PV #LV #SN Attr   VSize   VFree
  VolGroup00   1   2   0 wz--n- <38.97g    0 
```
2. Переименовываем Volume Group:
```
[root@packages vagrant]# vgrename VolGroup00 OtusRoot
  Volume group "VolGroup00" successfully renamed to "OtusRoot"
```
3. Правим __/etc/fstab, /etc/default/grub, /boot/grub2/grub.cfg__. Везде заменяем старое название на новое.
> [!NOTE]
> параметр __rd.lvm.lv__ в /etc/default/grub - активировать при загрузке только указанные логические тома

5. Пересоздаем initrd image, чтобы он знал новое название Volume Group:
```
[root@packages vagrant]# mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
...
...
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```
6. Перезагружаемся и проверяем что мы загрузились с новым именем Volume Group

#### ЗАДАНИЕ 3. Добавить модуль в intird

1. Скрипты модулей хранятся в каталоге /usr/lib/dracut/modules.d/. Для того, чтобы добавить свой модуль, создаем там папку с именем 01test
2. В этой папке поместим два скрипта:
- __module-setup.sh__, который устанавливает модуль и вызывает скрипт test.sh
```
    #!/bin/bash

check() {
    return 0
}

depends() {
    return 0
}

install() {
    inst_hook cleanup 00 "${moddir}/test.sh"
}
```
- __test.sh__ - сам вызываемый скрипт, который отрисовывает логотип linux
```
#!/bin/bash

exec 0<>/dev/console 1<>/dev/console 2<>/dev/console
cat <<'msgend'
Hello! You are in dracut module!
 ___________________
< I'm dracut module >
 -------------------
   \
    \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
msgend
sleep 10
echo " continuing...."
```
3. Пересобираем образ __initrd__:
```
[root@packages vagrant]# mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
...
...
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```
4. Чтобы проверить какие модули загружены в образ
```
[root@packages vagrant]# lsinitrd -m /boot/initramfs-$(uname -r).img
```
5. Для проверки убираем в /etc/default/grub параметры __rghb__ и __quiet__. Обновляем grub конфиг.
>[!NOTE]
>__rghb (redhat graphical boot)__ - this is a GUI mode booting screen with most of the information hidden while the user sees a rotating activity icon spining and brief information as to what the computer is doing 
>__quiet__ - hides the majority of boot messages before rhgb starts. These are supposed to make the common user more comfortable. They get alarmed about seeing the kernel and initializing messages, so they hide them for their comfort.
```
[root@packages vagrant]# grub2-mkconfig -o /boot/grub2/grub.cfg
```
Перезагружаемся и видим логотип linux при загрузке