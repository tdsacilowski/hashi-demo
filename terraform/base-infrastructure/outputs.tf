output "env_name" { value = "${var.env_name}" }

output "region" { value = "${data.aws_region.main.name}"}

output "base_os" { value = "${var.os}"}

output "instance_type" { value = "${var.instance_type}"}

output "consul_server_nodes" { value = "${var.consul_server_nodes}"}

output "vault_server_nodes" { value = "${var.vault_server_nodes}"}

output "vpc_id" { value = "${aws_vpc.main.id}" }

output "public_subnets" { value = ["${aws_subnet.main.*.id}"] }

output "sg_default_egress_id" { value = "${aws_security_group.default_egress.id}" }

output "sg_admin_access_id" { value = "${aws_security_group.admin_access.id}" }

output "sg_nomad_id" { value = "${aws_security_group.nomad.id}" }

output "instance_profile" { value = "${aws_iam_instance_profile.describe_instances.name}" }

output "key_pair_name" { value = "${aws_key_pair.main.key_name}" }

output "servers_consul" { value = ["${aws_instance.server_consul.*.public_ip}"] }

output "servers_vault" { value = ["${aws_instance.server_vault.*.public_ip}"] }
