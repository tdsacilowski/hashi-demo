#!/bin/bash

set -ex

# Wait for cloud-init to finish.
echo "Waiting 180 seconds for cloud-init to complete."
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo "Waiting ..."; sleep 2; done'

VAULT_VERSION=0.6.2

INSTANCE_PRIVATE_IP=$(ifconfig eth0 | grep "inet addr" | awk '{ print substr($2,6) }')

sudo apt-get -qq -y update

#######################################
# VAULT INSTALL
#######################################

# install dependencies
echo "Installing dependencies..."
sudo apt-get install -y unzip wget jq

# install vault
echo "Downloading Vault..."
cd /tmp/

wget -q https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip -O vault.zip

echo "Installing Vault..."
unzip vault.zip
rm vault.zip
sudo chmod +x vault
sudo mv vault /usr/bin/vault
sudo mkdir -pm 0600 /etc/vault.d

#######################################
# VAULT CONFIGURATION
#######################################

sudo tee /etc/vault.d/vault.hcl > /dev/null <<EOF
cluster_name = "${env_name}"

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

backend "consul" {
  path           = "vault"
  address        = "127.0.0.1:8500"
}

EOF

sudo tee /etc/init/vault.conf > /dev/null <<EOF
description "Vault"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

console log

script
  if [ -f "/etc/service/vault" ]; then
    . /etc/service/vault
  fi

  # Make sure to use all our CPUs, because Vault can block a scheduler thread
  export GOMAXPROCS=`nproc`

  exec /usr/bin/vault server \
    -config="/etc/vault.d/vault.hcl" \
    \$${VAULT_FLAGS} \
    >>/var/log/vault.log 2>&1
end script

EOF

#######################################
# START SERVICES
#######################################

sudo service vault start
