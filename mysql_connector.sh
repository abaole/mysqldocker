#!/bin/bash

echo "等待 MySQL 启动"
sleep 60

echo "master 创建同步用户"

mysql --host $MYSQL_SLAVE_IP -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e 'STOP SLAVE;';
mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'RESET SLAVE ALL;';

mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "CREATE USER '$MYSQL_REPLICATION_USER'@'%';"
mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"
mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'flush privileges;'

echo "* Set MySQL01 as master on MySQL02"

MYSQL01_Position=$(eval "mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_MASTER_PASSWORD -e 'show master status \G' | grep Position | sed -n -e 's/^.*: //p'")
MYSQL01_File=$(eval "mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_MASTER_PASSWORD -e 'show master status \G'     | grep File     | sed -n -e 's/^.*: //p'")
MASTER_IP=$(eval "getent hosts $MYSQL_MASTER_IP|awk '{print \$1}'")
echo $MASTER_IP
mysql --host $MYSQL_SLAVE_IP -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "CHANGE MASTER TO master_host='$MYSQL_MASTER_IP', master_port=3306, \
        master_user='$MYSQL_REPLICATION_USER', master_password='$MYSQL_REPLICATION_PASSWORD', master_log_file='$MYSQL01_File', \
        master_log_pos=$MYSQL01_Position;"

echo "* Set MySQL02 as master on MySQL01"

MYSQL02_Position=$(eval "mysql --host $MYSQL_SLAVE_IP -uroot -p$MYSQL_SLAVE_PASSWORD -e 'show master status \G' | grep Position | sed -n -e 's/^.*: //p'")
MYSQL02_File=$(eval "mysql --host $MYSQL_SLAVE_IP -uroot -p$MYSQL_SLAVE_PASSWORD -e 'show master status \G'     | grep File     | sed -n -e 's/^.*: //p'")

SLAVE_IP=$(eval "getent hosts $MYSQL_SLAVE_IP|awk '{print \$1}'")
echo $SLAVE_IP
mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "CHANGE MASTER TO master_host='$MYSQL_SLAVE_IP', master_port=3306, \
        master_user='$MYSQL_REPLICATION_USER', master_password='$MYSQL_REPLICATION_PASSWORD', master_log_file='$MYSQL02_File', \
        master_log_pos=$MYSQL02_Position;"

echo "* Start Slave on both Servers"
mysql --host $MYSQL_SLAVE_IP -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "start slave;"

echo "Increase the max_connections to 2000"
mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'set GLOBAL max_connections=2000';
mysql --host $MYSQL_SLAVE_IP -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e 'set GLOBAL max_connections=2000';

mysql --host $MYSQL_SLAVE_IP -uroot -p$MYSQL_SLAVE_PASSWORD -e "show slave status \G"

echo "master 状态"
mysql --host $MYSQL_MASTER_IP -uroot -p$MYSQL_SLAVE_PASSWORD -e "show master status"
echo "slave 状态"
mysql --host $MYSQL_SLAVE_IP -uroot -p$MYSQL_SLAVE_PASSWORD -e "show slave status \G"

echo "*** MySQL 主从同步已创建 ***"


