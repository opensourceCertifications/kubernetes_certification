#!/usr/bin/env bash
# mysql_startup.sh - Sets up MySQL environment



set -e

echo "[INFO] === Starting MySQL Setup ==="

# --------------------
# COMMON SETUP
# --------------------
echo "[INFO] Disabling SELinux"
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

echo "[INFO] Installing base packages and mysql"
sudo yum update -y
sudo yum upgrade -y
sudo yum -y install wget curl gnupg2 nmap-ncat mysql-server

#echo "[INFO] Setting MySQL server-id to $MYSQL_SERVER_ID"
#sudo cp /vagrant/mysql.conf /etc/my.cnf.d/mysql.cnf
#sudo sed -i "s/NUMBER/$MYSQL_SERVER_ID/g" /etc/my.cnf.d/mysql.cnf
#sudo chown root:root /etc/my.cnf.d/mysql.cnf

#echo "[INFO] Creating MySQL log directory"
#sudo mkdir -p /var/log/mysql
#sudo chown -R mysql:mysql /var/log/mysql

echo "[INFO] Starting MySQL"
sudo systemctl enable mysqld
sudo systemctl start mysqld

#echo "[INFO] Sleep 5s, then check for port 3306..."
#sleep 5
#if nc -z 127.0.0.1 3306; then
#echo "[INFO] MySQL appears to be listening on port 3306."
#else
#echo "[WARN] MySQL did not seem to start correctly or is not listening on 127.0.0.1:3306 yet."
#fi
#
## Set up root password and create replication user on database1 (master)
#if hostname | grep -q database1; then
#echo "[INFO] Setting up database1 as MASTER"
#sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'supersecurepassword'; FLUSH PRIVILEGES;"
#sudo mysql -u root -p"supersecurepassword" < /vagrant/setup.sql
#
## Get the binary log position for slave setup
#echo "[INFO] Getting master binary log position"
#sudo mysql -u root -p"supersecurepassword" -e "SHOW MASTER STATUS\G" > /vagrant/master_status.txt
#fi
#
## Configure database2 as slave
#if hostname | grep -q database2; then
#echo "[INFO] Setting up database2 as SLAVE"
#sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'supersecurepassword'; FLUSH PRIVILEGES;"
#
## Wait for master_status.txt to be created by database1
#echo "[INFO] Waiting for master status information..."
#sleep 10

#if [ -f /vagrant/master_status.txt ]; then
## Extract master log file and position
#MASTER_LOG_FILE=$(grep "File:" /vagrant/master_status.txt | awk '{print $2}')
#MASTER_LOG_POS=$(grep "Position:" /vagrant/master_status.txt | awk '{print $2}')

#echo "[INFO] Configuring slave with Master_Log_File=$MASTER_LOG_FILE, Master_Log_Pos=$MASTER_LOG_POS"

## Configure slave to replicate from master
#sudo mysql -u root -p"supersecurepassword" -e "
#STOP SLAVE;
#CHANGE MASTER TO
#  MASTER_HOST='192.168.58.10',
#  MASTER_USER='repl',
#  MASTER_PASSWORD='supersecurepassword',
#  MASTER_LOG_FILE='$MASTER_LOG_FILE',
#  MASTER_LOG_POS=$MASTER_LOG_POS;
#START SLAVE;
#"

## Check slave status
#echo "[INFO] Checking slave status"
#sudo mysql -u root -p"supersecurepassword" -e "SHOW SLAVE STATUS\G"
#else
#echo "[ERROR] Master status information not available. Manual configuration required."
#fi
#fi

echo "[INFO] === MySQL Setup Finished ==="

