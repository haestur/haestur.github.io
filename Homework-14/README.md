## OTUS Linux Professional - Урок 19. Docker: основы работы с контейнеризацией.

### OTUS Linux Professional Lesson #19 | Subject: Docker

#### Цель домашнего задания:
Разобраться с основами docker, с образом, эко системой docker в целом;

#### Описание домашнего задания
1. Установите Docker на хост машину
2. Установите Docker Compose - как плагин, или как отдельное приложение
3. Создайте свой кастомный образ nginx на базе alpine. После запуска nginx должен отдавать кастомную страницу (достаточно изменить дефолтную страницу nginx)
4. Определите разницу между контейнером и образом
5. Вывод опишите в домашнем задании.
6. Ответьте на вопрос: Можно ли в контейнере собрать ядро?

#### ЗАДАНИЕ 1. Установите Docker и Docker Compose на хост машину
Установка Docker Engine и Docker Compose - https://docs.docker.com/engine/install/

#### ЗАДАНИЕ 2. Создайте свой кастомный образ nginx на базе alpine. После запуска nginx должен отдавать кастомную страницу. Собранный образ необходимо запушить в docker hub.

1. Создаем образ из Dockerfile:
```
itbn@LearningMachine1$ docker build -t itbn/nginx .
```
2. Логинимся на docker hub
```
itbn@LearningMachine1$ docker login
```   
3. Загружаем образ в docker hub:
```
itbn@LearningMachine1$ docker push itbn/nginx
```
Ссылка на репозиторий с кастомным образом [itbn/nginx](https://hub.docker.com/repository/docker/itbn/nginx/general)

4. Проверяем загрузку и работу нашего docker образа.

Удаляем локальные образы и контейнеры:
```
itbn@LearningMachine1$ docker rm -v $(docker ps --filter status=exited -q)
itbn@LearningMachine1$ docker rmi $(docker images -q)
```
Запускаем контейнер (образ должен подгрузится с docker hub):
```
docker run -p "8080:80" itbn/nginx
```
В браузере на хосте должна открытся страничка по адресу http://127.0.0.1:8080


__Команды, которые использовались при выполнении задания:__

`docker build -t nginx . ` - создать образ с название nginx

`docker run -p "8080:80" nginx` - запустить контейнер из образа nginx (имя контейнера будет назанчено рандомно самим докером)

`docker exec -it brave_moore /bin/bash` - подключится к оболочке bash запущеного контейнера (здесь brave_moore - имя контейнера)

`docker ps -a ` - посмотреть список всех контейнеров

`docker ps ` - посмотреть список запущенных контейнеров

`docker rm objective_rubin` - удалить контейнер с именем objective_rubin

`docker rm -v $(docker ps --filter status=exited -q)` - удалить все контейнеры

`docker images` - посмотреть список установленных образов

`docker rmi $(docker images -q)` - удалить все образы

`docker search <image name>` - поиск образа в удалённом репозитории

`docker pull <image_name>` - cкачать образ из удалённого репозитория 

`docker login` - авторизация в docker hub 

`docker push <image_name>` - загрузить образ в личный удаленный репозиторий на Docker hub

#### ЗАДАНИЕ 3. Определите разницу между контейнером и образом
`Docker-контейнер` - это изолированная среда, в которой работают приложения, не затрагивая остальную часть системы, а система не влияет на приложение.

`Docker-образ` — это шаблон, из которого создаются контейнеры. Образ содержит инструкции для создание контейнера. Из образа можно запустить несколько контейнеров.

#### ЗАДАНИЕ 4. Ответьте на вопрос: Можно ли в контейнере собрать ядро?

Да, в контейнере можно собрать ядро. 


