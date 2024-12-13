## OTUS Linux Professional - Урок 42. Динамический веб.

#### Цель: 
- Получить практические навыки в настройке инфраструктуры с помощью манифестов и конфигураций;
- Отточить навыки использования ansible/vagrant/docker.

#### Описание домашнего задания
Варианты стенда:
- nginx + php-fpm (laravel/wordpress) + python (flask/django) + js(react/angular);
- nginx + java (tomcat/jetty/netty) + go + ruby;
- свои комбинации

Реализации на выбор:
- на хостовой системе через конфиги в /etc;
- деплой через docker-compose.

#### Процедура выполнения домашнего задания

Будем использовать вариант стенда __"nginx + php-fpm (wordpress) + python (django) + js(node.js)"__

В данном репозитории собранные все необходимые файлы для автоматической настройки стенда. Описание каталогов и файлов ниже.

- файл __Vagrantfile__ - содержит описание создания виртуальной машины на Ubuntu 22.04. На этой виртуальной машине в дальнейшем будем запускать docker-контейнеры
- файл __provision.yml__ - плейбук для Ansible, с помощью которого устанавливается Docker и отдается команда на запуск docker контейнеров
- каталог __project__ - содержит необходимые файлы для запуска docker-контейнеров
- каталог __project/nginx-conf__ - конфигурационные файлы nginx для обработки запросов к django, nodejs и wordpress
- каталог __project/node__ - содержит файл с настройками для node.js
- каталог __project/python__ - содержит файлы с настройками Django приложения
- файл __project/docker-compose.yml__ - содержит описание запуска docker-контейнеров
- файл __.env__ - содержит список переменных, которые используются при создании контейнеров

После развёртнывания стенда имеем виртуальную машину с именем __DynamicWeb__, на которой хостятся 5 докер контейнеров:
```
vagrant@DynamicWeb:~$ docker ps
CONTAINER ID   IMAGE                        COMMAND                  CREATED       STATUS       PORTS                                                                   NAMES
9910b7d4cce3   nginx:1.15.12-alpine         "nginx -g 'daemon of…"   5 hours ago   Up 5 hours   80/tcp, 0.0.0.0:8081-8083->8081-8083/tcp, :::8081-8083->8081-8083/tcp   nginx
f3bebd035601   wordpress:5.1.1-fpm-alpine   "docker-entrypoint.s…"   5 hours ago   Up 5 hours   9000/tcp                                                                wordpress
93d9e2d78224   project_app                  "gunicorn --workers=…"   5 hours ago   Up 5 hours                                                                           app
d5da71a14523   mariadb:10.8.2               "docker-entrypoint.s…"   5 hours ago   Up 5 hours   3306/tcp                                                                database
a8d382592ac5   node:16.13.2-alpine3.15      "docker-entrypoint.s…"   5 hours ago   Up 5 hours                                                                           node
```

Веб-сервер nginx принимает запросы по tcp портам 8081-8083, и проксирует их на сервера wordpress, node, project_app (django). Статика wordpress не проксируется, обрабатывается самим nginx.

В качестве базы данных для Wordpress используется MariaDB.

#### Дополнительные команды, которые использовались при выполнении домашнего задания:

`docker ps` - список запущенных контейнеров

`docker rm --force <id>` - удалить запущенный контейнер  

`docker-compose up -d <service>` - запустить только указанный сервис из docker-compose.yml

`docker-compose logs` - посмотреть логи сервисов

