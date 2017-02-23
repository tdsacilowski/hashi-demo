output "servers_nomad" {
  value = ["${aws_instance.server_nomad.*.public_ip}"]
}
output "clients" {
  value = ["${aws_instance.client.*.public_ip}"]
}
