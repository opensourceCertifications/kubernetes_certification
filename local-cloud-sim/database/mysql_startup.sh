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

echo "[INFO] Starting MySQL"
sudo systemctl enable mysqld
sudo systemctl start mysqld


echo "[INFO] === MySQL Setup Finished ==="

