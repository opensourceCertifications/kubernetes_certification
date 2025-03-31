ALTER USER 'root'@'localhost' IDENTIFIED BY 'supersecurepassword';

CREATE DATABASE IF NOT EXISTS dummydb;
CREATE USER IF NOT EXISTS 'dummyuser'@'%' IDENTIFIED BY 'supersecurepassword';
GRANT ALL PRIVILEGES ON dummydb.* TO 'dummyuser'@'%';
FLUSH PRIVILEGES;

-- Replication user
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'supersecurepassword';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;

