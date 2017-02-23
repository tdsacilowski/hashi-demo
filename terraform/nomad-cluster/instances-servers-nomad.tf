resource "aws_instance" "server_nomad" {
  ami           = "${module.shared.base_image}"
  instance_type = "${data.terraform_remote_state.base-infrastructure.instance_type}"
  key_name      = "${data.terraform_remote_state.base-infrastructure.key_pair_name}"
  subnet_id     = "${element(data.terraform_remote_state.base-infrastructure.public_subnets,count.index)}"

  iam_instance_profile = "${data.terraform_remote_state.base-infrastructure.instance_profile}"

  vpc_security_group_ids = [
    "${data.terraform_remote_state.base-infrastructure.sg_default_egress_id}",
    "${data.terraform_remote_state.base-infrastructure.sg_admin_access_id}",
    "${data.terraform_remote_state.base-infrastructure.sg_nomad_id}",
  ]

  tags {
    Name = "${data.terraform_remote_state.base-infrastructure.env_name}-server-nomad-${count.index}"
  }

  count = "${var.nomad_server_nodes}"

  connection {
    user        = "${module.shared.base_user}"
    private_key = "${file(module.shared.private_key_path)}"
  }

  //
  // Consul Client
  //
  provisioner "remote-exec" {
    inline = ["${module.shared.install_consul_client}"]
  }

  //
  // Nomad Server
  //
  provisioner "remote-exec" {
    inline = ["${module.shared.install_nomad_server}"]
  }

  provisioner "file" {
    source      = "${module.shared.path}/nomad/jobs"
    destination = "./"
  }
}
