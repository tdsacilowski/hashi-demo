data "template_file" "describe_instances" {
  template = "${file("${module.shared.path}/consul/iam/policy-ec2-describe-instances.json.tmpl")}"

  vars {
    region = "${data.aws_region.main.name}"
  }
}

resource "aws_iam_role" "ec2_assume_role" {
  name = "ec2-assume-role"

  assume_role_policy = "${file("${module.shared.path}/consul/iam/policy-ec2-assume-role.json")}"
}

resource "aws_iam_policy" "describe_instances" {
  name        = "describe-instances"
  description = "Describe Instances"
  policy      = "${data.template_file.describe_instances.rendered}"
}

resource "aws_iam_policy_attachment" "describe_instances_attchment" {
  name       = "describe-instances"
  roles      = ["${aws_iam_role.ec2_assume_role.name}"]
  policy_arn = "${aws_iam_policy.describe_instances.arn}"
}

resource "aws_iam_instance_profile" "describe_instances" {
  name  = "describe-instances"
  roles = ["${aws_iam_role.ec2_assume_role.name}"]
}
