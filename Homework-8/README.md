## OTUS Linux Professional - Урок 10. Управление пакетами. Дистрибьюция софта.

#### ЦЕЛЬ ДЗ:
1. Создать свой RPM пакет (будем собирать nginx с поддержкой openssl)
2. Создать свой репозиторий и разместить там ранее собранный RPM

#### ЗАДАНИЕ 1: Создать свой RPM пакет
1. Устанавливаем пакеты:
```
[root@packages ~]# yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc
```
2. Загружаем SRPM (исходники) nginx'a:
```
[root@packages ~]# wget https://nginx.org/packages/centos/8/SRPMS/nginx-1.20.2-1.el8.ngx.src.rpm
```
3. Устанавливаем только что скаченный пакет. При установке srpm в домашней директории создается древо каталогов для сборки:
```
[root@packages ~]# rpm -i nginx-1.20.2-1.el8.ngx.src.rpm
```
4. Скачиваем и распаковываем исходник для openssl, он потребуется при сборке:
```
[root@packages ~]# wget https://www.openssl.org/source/openssl-1.1.1k.tar.gz
[root@packages ~]# tar -xzfv openssl-1.1.1k.tar.gz
```
5. Заранее поставим все зависимости, чтобы в процессе сборки не было ошибок:
```
[root@packages ~]# yum-builddep rpmbuild/SPECS/nginx.spec
```
6. Правим spec файл:
```
...
%build
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --with-debug \
    --with-openssl=/tmp/openssl-1.1.1k
...
```
7. Собираем новый rpm пакет:
```
[root@packages ~]# rpmbuild -bb rpmbuild/SPECS/nginx.spec
```
8. Убедимся, что пакеты создались:
```
[root@packages ~]# ll rpmbuild/RPMS/x86_64/
```
9. Теперь можно установить наш пакет и убедиться, что nginx работает:
```
[root@packages ~]# yum localinstall rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el8.ngx.x86_64.rpm
[root@packages ~]# systemctl start nginx
[root@packages ~]# systemctl status nginx
```
Далее мы будем использовать его для доступа к своему репозиторию

#### ЗАДАНИЕ 2. Создать свой репозиторий и разместить там ранее собранный RPM

1. Создаем каталог репозитория в дефолтном каталоге статики nginx:
```
[root@packages ~]# mkdir /usr/share/nginx/html/repo
```
2. Копируем в него наш собранный пакет и дополнительно Percona Server:
```
[root@packages ~]# cp rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el8.ngx.x86_64.rpm /usr/share/nginx/html/repo
[root@packages ~]# wget https://downloads.percona.com/downloads/percona-distribution-mysql-ps/percona-distribution-mysql-ps-8.0.28/binary/redhat/8/x86_64/percona-orchestrator-3.2.6-2.el8.x86_64.rpm \
-O /usr/share/nginx/html/repo/percona-orchestrator-3.2.6-2.el8.x86_64.rpm
```
3. Инициализируем репозиторий:
```
[root@packages ~]# createrepo /usr/share/nginx/html/repo/
```
4. Настраиваем nginx для листинга каталога резитория. Добавляем в файл `/etc/nginx/conf.d/default.conf` в секцию `location /` директиву `autoindex on`

5. Проверяем синтаксис и перезапускаем nginx:
```
[root@packages ~]# nginx -t
[root@packages ~]# nginx -s reload
```
6. Проверяем что репозиторий доступен:
```
[root@packages ~]# lynx http://localhost/repo/
[root@packages ~]# curl -a http://localhost/repo/
```
7. Тестируем установку с нашего репозитория. Добавляем репозиторий в систему:
```
[root@packages ~]# cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
```
8. Убедимся что репозиторий подключился:
```
[root@packages ~]# yum repolist enabled | grep otus
[root@packages ~]# yum list | grep otus
```
9. Попробуем установить с него пакет:
[root@packages ~]# yum install percona-orchestrator.x86_64 -y

> [!NOTE]
> В случае, если потребуется обновить репозиторий (а это делается при каждом добавлении файлов) снова, нужно выполнить команду `createrepo/usr/share/nginx/html/repo/`

