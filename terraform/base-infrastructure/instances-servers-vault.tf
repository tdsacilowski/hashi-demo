data "template_file" "vault-auth-setup" {
  template = "${file("${module.shared.path}/vault/demo/initial-auth-setup.sh.tpl")}"

  vars {
    base_ami = "${module.shared.base_image}"
  }
}

resource "aws_instance" "server_vault" {
  ami = "${module.shared.base_image}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.main.key_name}"
  subnet_id     = "${element(aws_subnet.main.*.id,count.index)}"

  iam_instance_profile = "${aws_iam_instance_profile.describe_instances.name}"

  vpc_security_group_ids = [
    "${aws_security_group.default_egress.id}",
    "${aws_security_group.admin_access.id}",
    "${aws_security_group.nomad.id}",
  ]

  tags {
    Name = "${var.env_name}-server-vault-${count.index}"
  }

  count = "${var.vault_server_nodes}"

  connection {
    user = "${module.shared.base_user}"
    private_key = "${file("${module.shared.path}/ssh_keys/demo.pem")}"
  }

  //
  // Consul Client
  //
  provisioner "remote-exec" {
    inline = ["${module.shared.install_consul_client}"]
  }

  //
  // Vault Server
  //
  provisioner "remote-exec" {
    inline = [
      "${module.shared.install_vault_server}",
      "echo 'export VAULT_ADDR=http://localhost:8200' >> /home/${module.shared.base_user}/.bashrc",
    ]
  }

  provisioner "file" {
    source      = "${module.shared.path}/vault/demo"
    destination = "./"
  }

  provisioner "file" {
    content = "${data.template_file.vault-auth-setup.rendered}"
    destination = "./demo/initial-auth-setup.sh"
  }

  provisioner "remote-exec" {
    inline = ["chmod -R +x ./demo"]
  }
}
