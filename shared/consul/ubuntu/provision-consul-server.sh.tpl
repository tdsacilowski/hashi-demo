#!/bin/bash

set -ex

# Wait for cloud-init to finish.
echo "Waiting 180 seconds for cloud-init to complete."
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo "Waiting ..."; sleep 2; done'

CONSUL_VERSION=0.7.1
CONSUL_TEMPLATE_VERSION=0.16.0

INSTANCE_ID=`curl ${instance_id_url}`
INSTANCE_PRIVATE_IP=$(ifconfig eth0 | grep "inet addr" | awk '{ print substr($2,6) }')

sudo apt-get -qq -y update

#######################################
# CONSUL INSTALL
#######################################

# install dependencies
echo "Installing consul dependencies..."
sudo apt-get -qq -y update
sudo apt-get install -qq -y unzip wget

# install consul
echo "Fetching consul..."
cd /tmp/

wget -q https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip -O consul.zip

echo "Installing consul..."
unzip consul.zip
rm consul.zip
sudo chmod +x consul
sudo mv consul /usr/bin/consul
sudo mkdir -pm 0600 /etc/consul.d

# setup consul directories
sudo mkdir -pm 0600 /opt/consul
sudo mkdir -p /opt/consul/data

echo "Consul installation complete."

#######################################
# CONSUL CONFIGURATION
#######################################

sudo tee /etc/consul.d/config.json > /dev/null <<EOF
{
  "node_name": "$$INSTANCE_ID",

  "data_dir": "/opt/consul/data",
  "ui": true,

  "client_addr": "0.0.0.0",
  "bind_addr": "0.0.0.0",
  "advertise_addr": "$$INSTANCE_PRIVATE_IP",

  "leave_on_terminate": false,
  "skip_leave_on_interrupt": true,

  "retry_join_ec2": {
    "tag_key": "consul_server_datacenter",
    "tag_value": "${region}"
  },

  "datacenter": "${region}",
  "server": true,
  "bootstrap_expect": ${consul_server_nodes}
}
EOF

sudo tee /etc/init/consul.conf > /dev/null <<EOF
description "Consul"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

console log

script
  if [ -f "/etc/service/consul" ]; then
    . /etc/service/consul
  fi

  # Make sure to use all our CPUs, because Consul can block a scheduler thread
  export GOMAXPROCS=`nproc`

  exec /usr/bin/consul agent \
    -config-dir="/etc/consul.d" \
    $${CONSUL_FLAGS} \
    >>/var/log/consul.log 2>&1
end script

EOF

#######################################
# CONSUL-TEMPLATE INSTALL
#######################################

# install dependencies
echo "Installing consul-template dependencies..."
sudo apt-get -qq -y update
sudo apt-get install -qq -y unzip wget

# install consul-template
echo "Fetching consul-template..."
cd /tmp/

wget -q https://releases.hashicorp.com/consul-template/$${CONSUL_TEMPLATE_VERSION}/consul-template_$${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip -O consul-template.zip

echo "Installing consul-template..."
unzip consul-template.zip
rm consul-template.zip
sudo chmod +x consul-template
sudo mv consul-template /usr/bin/consul-template

echo "Consul-template installation complete."

#######################################
# DNSMASQ INSTALL
#######################################

echo "Installing Dnsmasq..."

sudo apt-get -qq -y update
sudo apt-get -qq -y install dnsmasq-base dnsmasq

echo "Configuring Dnsmasq..."

sudo sh -c 'echo "server=/consul/127.0.0.1#8600" >> /etc/dnsmasq.d/consul'
sudo sh -c 'echo "listen-address=127.0.0.1" >> /etc/dnsmasq.d/consul'
sudo sh -c 'echo "bind-interfaces" >> /etc/dnsmasq.d/consul'

echo "Restarting dnsmasq..."
sudo service dnsmasq restart

echo "dnsmasq installation complete."

#######################################
# START SERVICES
#######################################

sudo service consul start
