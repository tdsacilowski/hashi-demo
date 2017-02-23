resource "aws_vpc" "main" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }

  tags {
    Name = "${var.env_name}"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = "${element(aws_subnet.main.*.id,count.index)}"
  route_table_id = "${aws_route_table.main.id}"

  count = "${length(var.vpc_cidrs)}"
}

resource "aws_subnet" "main" {
  vpc_id                  = "${aws_vpc.main.id}"
  availability_zone       = "${element(data.aws_availability_zones.main.names,count.index)}"
  cidr_block              = "${element(var.vpc_cidrs,count.index)}"
  map_public_ip_on_launch = true

  count = "${length(var.vpc_cidrs)}"

  tags {
    Name = "${var.env_name}"
  }
}
