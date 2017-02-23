//
// Providers
//
provider "aws" {
  region = "us-east-1"
}

//
// Data Sources
//
# Refers to remote state on local filesystem to obtain information about the initial infrastructure setup
data "terraform_remote_state" "base-infrastructure" {
  backend = "local"
  config {
    path = "${path.module}/../base-infrastructure/terraform.tfstate"
  }
}

//
// Variables
//
# Overrides the default value of 3 in module "shared".
# This is to simplify testing. Prod values should be 3, 5, or 7 for proper leader election.
variable "nomad_server_nodes" {
  default = "1"
}

variable "client_nodes" {
  default = "3"
}

# Pre-baked AMI using Packer (see [PROJECT_ROOT]/packer/nomad-client)
variable "client_ami" {
  default = "ami-5a885f4c"
}

//
// Modules
//
module "shared" {
  source = "../../shared"

  env_name            = "${data.terraform_remote_state.base-infrastructure.env_name}"
  region              = "${data.terraform_remote_state.base-infrastructure.region}"
  os                  = "${data.terraform_remote_state.base-infrastructure.base_os}"

  consul_server_nodes = "${data.terraform_remote_state.base-infrastructure.consul_server_nodes}"
  nomad_server_nodes  = "${var.nomad_server_nodes}"
}
