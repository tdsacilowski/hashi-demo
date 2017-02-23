#!/bin/bash

set -ex

# Wait for cloud-init to finish.
echo "Waiting 180 seconds for cloud-init to complete."
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo "Waiting ..."; sleep 2; done'

NOMAD_VERSION=0.5.4

INSTANCE_ID=`curl ${instance_id_url}`
INSTANCE_PRIVATE_IP=$(ifconfig eth0 | grep "inet addr" | awk '{ print substr($2,6) }')

sudo apt-get -qq -y update

#######################################
# NOMAD INSTALL
#######################################

# install dependencies
echo "Installing dependencies..."
sudo apt-get install -qq -y wget unzip jq

# install nomad
echo "Fetching nomad..."
cd /tmp/

wget -q https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip -O nomad.zip

echo "Installing nomad..."
unzip nomad.zip
rm nomad.zip
sudo chmod +x nomad
sudo mv nomad /usr/bin/nomad
sudo mkdir -pm 0600 /etc/nomad.d

# setup nomad directories
sudo mkdir -pm 0600 /opt/nomad
sudo mkdir -p /opt/nomad/data

echo "Nomad installation complete."

#######################################
# NOMAD CONFIGURATION
#######################################

VAULT_SERVICE_ADDRESS=`curl -s -H 'Accept: application/json' localhost:8500/v1/catalog/service/vault | jq -r .[0].ServiceAddress`
VAULT_SERVICE_PORT=`curl -s -H 'Accept: application/json' localhost:8500/v1/catalog/service/vault | jq -r .[0].ServicePort`

# IMPORTANT: This is just to illustrate functionality.In a production environment,
# you would not output this value to the configuration file, as I am doing below
VAULT_AWS_EC2_TOKEN=`curl -s -X POST "$$VAULT_SERVICE_ADDRESS:$$VAULT_SERVICE_PORT/v1/auth/aws-ec2/login" -d '{"role":"nomad-cluster","pkcs7":"'$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/pkcs7 | tr -d '\n')'"}' | jq -r .auth.client_token`

sudo tee /etc/nomad.d/nomad.hcl > /dev/null <<EOF
name       = "$$INSTANCE_ID"
data_dir   = "/opt/nomad/data"
datacenter = "${region}"

bind_addr = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = ${nomad_server_nodes}
}

addresses {
  rpc  = "$$INSTANCE_PRIVATE_IP"
  serf = "$$INSTANCE_PRIVATE_IP"
}

advertise {
  http = "$$INSTANCE_PRIVATE_IP:4646"
}

consul {
}

vault {
  enabled = true
  address = "http://$$VAULT_SERVICE_ADDRESS:$$VAULT_SERVICE_PORT"
  token   = "$$VAULT_AWS_EC2_TOKEN"
  create_from_role = "nomad-cluster"
}

EOF

sudo tee /etc/init/nomad.conf > /dev/null <<EOF
description "Nomad"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

console log

script
  if [ -f "/etc/service/nomad" ]; then
    . /etc/service/nomad
  fi

  exec /usr/bin/nomad agent \
    -config="/etc/nomad.d" \
    $${NOMAD_FLAGS} \
    >>/var/log/nomad.log 2>&1
end script

EOF

#######################################
# START SERVICES
#######################################

sudo service nomad start
