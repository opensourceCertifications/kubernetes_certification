#!/usr/bin/env bash
set -e

echo "[INFO] Disabling SELinux to avoid blocked ports"
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

echo "[INFO] Installing base packages: wget, curl, gnupg, netcat"
sudo yum -y install wget curl gnupg2 nmap-ncat

# --------------------
# MONGODB SETUP
# --------------------
echo "[INFO] Setting up MongoDB repository for AlmaLinux 9"
sudo tee /etc/yum.repos.d/mongodb-org-6.0.repo > /dev/null <<EOF
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-6.0.asc
EOF

echo "[INFO] Installing MongoDB"
sudo yum -y install mongodb-org

# Overwrite with your custom config
echo "[INFO] Copying /vagrant/mongo.conf => /etc/mongod.conf"
sudo cp /vagrant/mongo.conf /etc/mongod.conf
sudo sed -i 's/bindIp:.*$/bindIp: 0.0.0.0/' /etc/mongod.conf

# Ensure MongoDB data directory exists
echo "[INFO] Creating MongoDB data directory..."
sudo mkdir -p /var/lib/mongodb
sudo chown -R mongod:mongod /var/lib/mongodb


echo "[INFO] Starting MongoDB"
sudo systemctl enable mongod
sudo systemctl start mongod

# Wait for mongod
echo "[INFO] Sleep 5s, then wait for port 27017..."
sleep 5
#until nc -z 127.0.0.1 27017; do
#  echo "[INFO] Waiting for MongoDB to accept connections..."
#  sleep 2
#done

# Only run the Mongo init script on database1
if hostname | grep -q database1; then
  echo "[INFO] Initiating MongoDB replica set (setup.js)"
  mongosh --host localhost < /vagrant/setup.js
fi

# --------------------
# MYSQL SETUP
# --------------------
echo \"[INFO] Adding MySQL 8 community repo for AlmaLinux 9\"
sudo yum -y install https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm

echo \"[INFO] Installing MySQL server\"
sudo yum -y install mysql-community-server

echo \"[INFO] Copying /vagrant/mysql.conf => /etc/my.cnf\"
sudo cp /vagrant/mysql.conf /etc/my.cnf

# If second node => server-id=2
if hostname | grep -q database2; then
  echo \"[INFO] Setting MySQL server-id=2\"
  sudo sed -i 's/^server-id.*/server-id = 2/' /etc/my.cnf
fi

echo \"[INFO] Starting MySQL\"
sudo systemctl enable mysqld
sudo systemctl start mysqld

# Wait for MySQL
echo \"[INFO] Sleep 5s, then wait for port 3306...\"
sleep 5
until nc -z 127.0.0.1 3306; do
  echo \"[INFO] Waiting for MySQL to accept connections...\"
  sleep 2
done

# Only run setup.sql on database1
if hostname | grep -q database1; then
  echo \"[INFO] Running MySQL setup.sql for primary node\"
  sudo mysql < /vagrant/setup.sql
fi


