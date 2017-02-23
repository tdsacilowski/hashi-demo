//
// Providers
//
provider "aws" {
  region = "us-east-1"
}

//
// Variables
//
variable "env_name" {
  default = "consul-nomad-vault"
}

variable "os" {
  default = "ubuntu"
}

variable "key_name" {
  default = "demo"
}

variable "instance_type" {
  default = "t2.small"
}

variable "vpc_cidr" {
  default = "10.150.0.0/16"
}

variable "vpc_cidrs" {
  type = "list"

  default = [
    "10.150.11.0/24",
    "10.150.12.0/24",
  ]
}

# Overrides the default value of 3 in module "shared".
# This is to simplify testing. Prod values should be 3, 5, or 7 for proper leader election.
variable "consul_server_nodes" {
  default = "1"
}

variable "vault_server_nodes" {
  default = "1"
}

//
// Data Sources
//
data "aws_region" "main" {
  current = true
}

data "aws_availability_zones" "main" {}

//
// Modules
//
module "shared" {
  source = "../../shared"

  os                  = "${var.os}"
  region              = "${data.aws_region.main.name}"
  env_name            = "${var.env_name}"
  consul_server_nodes = "${var.consul_server_nodes}"
}
