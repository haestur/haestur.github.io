## OTUS Linux Professional - Урок 44. MySQL: Backup + Репликация.

#### ЦЕЛЬ: Настроить репликацию MySQL

#### Описание домашнего задания:

Развернуть базу данных на мастере, и реплицировать на слейв таблицы __bookmaker, competition, market, odds, outcome__.
Репликация должна выполнятся с помощью __GTID__

#### Процедура выполнения домашнего задания

Поднимаем две виртуальные машины - master и slave. Master - основная БД, slave - реплика с master'а:
```console
# vagrant up
```
Устанавливаем на обе машины __Percona Server for MySQL 5.7__
```console
[root@master ~]# sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
[root@master ~]# sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
[root@master ~]# sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
[root@master ~]# yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
[root@master ~]# percona-release setup ps57
[root@master ~]# yum install Percona-Server-server-57
```
Те же действия повторяем на slave.

По умолчанию Percona хранит файлы в таком виде:
- основной конфиг в /etc/my.cnf
- так же инклюдится директория /etc/my.cnf.d/ - куда мы и будем складывать наши конфиги.
- data файлы в /var/lib/mysql

Копируем заранее подготовленные конфиги:
```console
[root@master ~]# cp /vagrant/conf.d/* /etc/my.cnf.d/
```
Запускаем службу MySQL:
```console
[root@master ~]# systemctl start mysql
[root@master ~]# systemctl status mysql
● mysqld.service - MySQL Server
   Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2024-08-29 05:50:28 UTC; 9min ago
     Docs: man:mysqld(8)
           http://dev.mysql.com/doc/refman/en/using-systemd.html
  Process: 908 ExecStart=/usr/sbin/mysqld --daemonize --pid-file=/var/run/mysqld/mysqld.pid $MYSQLD_OPTS (code=exited, status=0/SUCCESS)
  Process: 598 ExecStartPre=/usr/bin/mysqld_pre_systemd (code=exited, status=0/SUCCESS)
 Main PID: 911 (mysqld)
   CGroup: /system.slice/mysqld.service
           └─911 /usr/sbin/mysqld --daemonize --pid-file=/var/run/mysqld/mysqld.pid

Aug 29 05:50:25 master systemd[1]: Starting MySQL Server...
Aug 29 05:50:28 master systemd[1]: Started MySQL Server.
```
Те же действия выполняем на slave.

При установке Percona автоматически генерирует пароль для пользователя root и кладет его в файл /var/log/mysqld.log:
```console
[root@master ~]# cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $11}'
jr%#OgIpv5C;
```
Меняем пароль:
```console
[root@master ~]# mysql -uroot -p'jr%#OgIpv5C;'
```
```mysql
mysql> ALTER USER USER() IDENTIFIED BY 'R6S4#21#.3@31Fsd';
```
Репликацию будем настраивать с использованием __GTID__. GTID представляет собой уникальный 128-битный глобальный идентификационный номер (SERVER_UUID), который увеличивается с каждой новой транзакцией.

Следует обратить внимание, что атрибут server-id на мастер-сервере должен обязательно отличаться от server-id слейв-сервера. Проверить какая переменная установлена на текущий момент можно следующим образом:
```mysql
mysql> SELECT @@server_id;
+-------------+
| @@server_id |
+-------------+
|           1 |
+-------------+
1 row in set (0.00 sec)
```
Параметр __server-id__ у нас прописан в конфигурационном файле __etc/my.cnf.d/01-base.cnf__. Соответственно на slave его нужно изменить и перезагрузить mysql. 

Убеждаемся что GTID включён:
```mysql
mysql> SHOW VARIABLES LIKE 'gtid_mode';
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| gtid_mode     | ON    |
+---------------+-------+
1 row in set (0.01 sec)
```
Создадим тестовую базу __bet__ на master'е, загрузим в нее дамп и проверим:
```mysql
mysql> CREATE DATABASE bet;
Query OK, 1 row affected (0.00 sec)
```
```console
[root@slave ~]# mysql -uroot -p -D bet < /vagrant/bet.dmp
Enter password:
```
```mysql
mysql> USE bet;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> SHOW TABLES;
+------------------+
| Tables_in_bet    |
+------------------+
| bookmaker        |
| competition      |
| events_on_demand |
| market           |
| odds             |
| outcome          |
| v_same_event     |
+------------------+
7 rows in set (0.00 sec)
```
Создадим пользователя для репликации и дадим ему права на эту самую репликацию:
```mysql
mysql> CREATE USER 'repl'@'%' IDENTIFIED BY '!OtusLinux2024';
Query OK, 0 rows affected (0.00 sec)
mysql> SELECT user,host FROM mysql.user where user='repl';
+------+------+
| user | host |
+------+------+
| repl | %    |
+------+------+
1 row in set (0.00 sec)
mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%' IDENTIFIED BY '!OtusLinux2024';
Query OK, 0 rows affected, 1 warning (0.00 sec)
```
Дампим базу для последующего залива на slave и игнорируем таблицы по заданию:
```console
[root@master ~]# mysqldump --all-databases --triggers --routines --master-data --ignore-table=bet.events_on_demand --ignore-table=bet.v_same_event -uroot -p > master.sql
Enter password: 
Warning: A partial dump from a server that has GTIDs will by default include the GTIDs of all transactions, even those that changed suppressed parts of the database. If you don't want to restore GTIDs, pass --set-gtid-purged=OFF. To make a complete dump, pass --all-databases --triggers --routines --events.
```
На слейве раскомментируем в __/etc/my.cnf.d/05-binlog.cnf__ строки:
```console
#replicate-ignore-table=bet.events_on_demand
#replicate-ignore-table=bet.v_same_event
```
Таким образом указываем таблицы которые будут игнорироваться при репликации.

Заливаем на слейв дамп мастера и убеждаемся что база есть и она без лишних таблиц:
```mysql
mysql> RESET MASTER;
mysql> SOURCE /mnt/master.sql
mysql> SHOW DATABASES LIKE 'bet';
+----------------+
| Database (bet) |
+----------------+
| bet            |
+----------------+
1 row in set (0.00 sec)
mysql> USE bet;
Database changed
mysql> SHOW TABLES;
+---------------+
| Tables_in_bet |
+---------------+
| bookmaker     |
| competition   |
| market        |
| odds          |
| outcome       |
+---------------+
5 rows in set (0.00 sec)
```
Видим что таблиц v_same_event и events_on_demand нет.

Подключаем и запускаем slave:
```mysql
mysql> SHOW SLAVE STATUS\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.56.10
                  Master_User: repl
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000002
          Read_Master_Log_Pos: 119568
               Relay_Log_File: slave-relay-bin.000002
                Relay_Log_Pos: 414
        Relay_Master_Log_File: mysql-bin.000002
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: bet.events_on_demand,bet.v_same_event
      Replicate_Wild_Do_Table: 
```

Видно что репликация работает, gtid работает и игнорятся таблички по заданию. 

Проверим репликацию в действии. На мастере:
```mysql
mysql> USE bet;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet');
Query OK, 1 row affected (0.00 sec)

mysql> SELECT * FROM bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```

На слейве:
```mysql
mysql> SELECT * FROM bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```

В binlog-ах на cлейве также видно последнее изменение, туда же он пишет информацию о GTID:
```mysql
mysql> SHOW BINLOG EVENTS
    -> ;
+------------------+-----+----------------+-----------+-------------+------------------------------------------------------------------------+
| Log_name         | Pos | Event_type     | Server_id | End_log_pos | Info                                                                   |
+------------------+-----+----------------+-----------+-------------+------------------------------------------------------------------------+
| mysql-bin.000001 |   4 | Format_desc    |         2 |         123 | Server ver: 5.7.44-48-log, Binlog ver: 4                               |
| mysql-bin.000001 | 123 | Previous_gtids |         2 |         154 |                                                                        |
| mysql-bin.000001 | 154 | Gtid           |         1 |         219 | SET @@SESSION.GTID_NEXT= '9566d66a-66af-11ef-b129-5254004d77d3:40'     |
| mysql-bin.000001 | 219 | Query          |         1 |         292 | BEGIN                                                                  |
| mysql-bin.000001 | 292 | Query          |         1 |         419 | use `bet`; INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet') |
| mysql-bin.000001 | 419 | Xid            |         1 |         450 | COMMIT /* xid=378 */                                                   |
+------------------+-----+----------------+-----------+-------------+------------------------------------------------------------------------+
6 rows in set (0.00 sec)
```
