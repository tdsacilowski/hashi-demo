variable "region" {}
variable "env_name" {}

variable "os" {
  default = "ubuntu"
}

variable "consul_server_nodes" {
  default = "3"
}

variable "nomad_server_nodes" {
  default = "3"
}

output "path" {
  value = "${path.module}"
}

output "public_key_path" {
  value = "${path.module}/ssh_keys/demo.pub"
}

output "private_key_path" {
  value = "${path.module}/ssh_keys/demo.pem"
}
