#!/usr/bin/env bash

set -ex

# Write demo policy to Vault
vault policy-write secret demo-acl.hcl

# Get and write nomad-server policy to Vault
# This allows Nomad to integrate with Vault and request tokens
curl https://nomadproject.io/data/vault/nomad-server-policy.hcl -O -s -L
vault policy-write nomad-server nomad-server-policy.hcl

# Get and write nomad-cluster-role
# This defines the nomad-cluster role which will be granted appropriate policies and used for aws-ec2 auth
curl https://nomadproject.io/data/vault/nomad-cluster-role.json -O -s -L
vault write /auth/token/roles/nomad-cluster @nomad-cluster-role.json

# Enable and configure the aws-ec2 auth backend for secure introduction
# based on the base_ami used for the Vault server(s)
vault auth-enable aws-ec2
vault write -f auth/aws-ec2/config/client
vault write auth/aws-ec2/role/nomad-cluster bound_ami_id=${base_ami} policies=secret,nomad-server max_ttl=500h
