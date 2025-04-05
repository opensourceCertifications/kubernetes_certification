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

echo "[INFO] Installing base packages"
sudo yum -y install wget curl gnupg2 nmap-ncat

# --------------------
# MYSQL SETUP
# --------------------
echo "[INFO] Adding MySQL 8 community repo"
sudo yum -y install https://repo.mysql.com/mysql80-community-release-el9-1.noarch.rpm

echo "[INFO] Cleaning cache and importing GPG key"
sudo yum clean all
sudo rm -f /etc/pki/rpm-gpg/*mysql*
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023

echo "[INFO] Installing MySQL server"
sudo yum -y install mysql-community-server

echo "[INFO] Copying /vagrant/mysql.conf => /etc/my.cnf"
sudo cp /vagrant/mysql.conf /etc/my.cnf
sudo sed -i "s/NUMBER/$MYSQL_SERVER_ID/g" /etc/my.cnf

# Set server-id=2 for replication on second node
#if hostname | grep -q database2; then
#  echo "[INFO] Setting MySQL server-id=2"
#  sudo sed -i 's/^server-id.*/server-id = 2/' /etc/my.cnf
#fi

echo "[INFO] Creating MySQL data directory"
sudo mkdir -p /var/lib/mysql
sudo chown -R mysql:mysql /var/lib/mysql

echo "[INFO] Creating MySQL log directory"
sudo mkdir -p /var/log/mysql
sudo chown -R mysql:mysql /var/log/mysql

# echo "[INFO] Initializing MySQL data directory (Currently Commented Out)..."
# if [ ! -d "/var/lib/mysql/mysql" ]; then
#   sudo mysqld --initialize-insecure --user=mysql
# fi

echo "[INFO] Starting MySQL"
#sudo systemctl enable mysqld
#sudo systemctl start mysqld

#echo "[INFO] Sleep 5s, then check for port 3306..."
#sleep 5
#if nc -z 127.0.0.1 3306; then
#  echo "[INFO] MySQL appears to be listening on port 3306."
#else
#  echo "[WARN] MySQL did not seem to start correctly or is not listening on 127.0.0.1:3306 yet."
#fi

 #echo "[INFO] Setting root password and running setup.sql (Currently Commented Out)..."
 #if hostname | grep -q database1; then
 #    sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'supersecurepassword'; FLUSH PRIVILEGES;"
 #    sudo mysql -u root -p"supersecurepassword" < /vagrant/setup.sql
 #fi

echo "[INFO] === MySQL Setup Finished ==="
