#!/usr/bin/env bash
# mongo_startup.sh - Sets up MongoDB environment
set -e

echo "[INFO] Disabling SELinux"
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config


# --------------------
# MONGODB SETUP
# --------------------
echo "[INFO] Setting up MongoDB repository"
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

echo "[INFO] Copying /vagrant/mongo.conf => /etc/mongod.conf"
sudo cp /vagrant/mongo.conf /etc/mongod.conf
sudo sed -i 's/bindIp:.*$/bindIp: 0.0.0.0/' /etc/mongod.conf

echo "[INFO] Creating MongoDB data directory"
sudo mkdir -p /var/lib/mongodb
sudo mkdir -p /var/log/mongodb
sudo chown -R mongod:mongod /var/lib/mongodb
sudo chown -R mongod:mongod /var/log/mongodb
sudo chmod 755 /var/lib/mongodb
sudo chmod 755 /var/log/mongodb

echo "[INFO] Starting MongoDB"
sudo systemctl enable mongod
sudo systemctl start mongod

echo "[INFO] Sleep 5s, then check for port 27017..."
sleep 5

#until nc -z 127.0.0.1 27017; do
#  echo "[INFO] Waiting for MongoDB to accept connections..."
#  sleep 2
#done

# Initiate replica set only on database1
if hostname | grep -q database1; then
  echo "[INFO] Waiting for database2 to be available before initiating replica set..."
  # Wait up to 60 seconds for database2 to come online
  for i in {1..12}; do
    if ping -c1 -W5 192.168.58.11 &>/dev/null; then
      echo "[INFO] database2 is reachable, waiting 15 more seconds for MongoDB to start on database2..."
      sleep 15
      echo "[INFO] Initiating MongoDB replica set (setup.js)"
      mongosh --host localhost < /vagrant/setup.js
      break
    else
      echo "[INFO] database2 not yet reachable, waiting (attempt $i of 12)..."
      sleep 5
    fi
    
    if [ $i -eq 12 ]; then
      echo "[WARN] Couldn't reach database2, skipping replica set initialization for now."
      echo "[WARN] You may need to manually run: mongosh --host localhost < /vagrant/setup.js"
    fi
  done
fi

echo "[INFO] === MongoDB Setup Finished ==="

