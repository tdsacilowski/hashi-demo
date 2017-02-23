#!/usr/bin/env bash

set -ex

# Get the MySQL root password from the user
echo "Enter the MySQL root password:"
read MYSQL_PWD

# Enable the mysql dynamic secrets backend and create readonly and modify roles
# This will be used by the Wordpress Nomad job to connect to the MySQL container deployed by Nomad
vault mount mysql
vault write mysql/config/connection \
    connection_url="root:${MYSQL_PWD}@tcp(mysql.service.consul:3306)/"
vault write mysql/roles/modify \
    sql="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON *.* TO '{{name}}'@'%';"
vault write mysql/roles/readonly \
    sql="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"
