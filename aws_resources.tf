resource "aws_vpc" "vpc" {
  cidr_block = "${var.vpc_cidr}"
}


resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}


resource "aws_subnet" "vpc_subnet" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.vpc_cidr}"
  map_public_ip_on_launch = false
}


resource "aws_instance" "consulserver" {
  ami                         = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.vpc_subnet.id}"
  vpc_security_group_ids      = ["${aws_security_group.vpc.id}"]
  associate_public_ip_address = "true"
  key_name                    = "${var.sshkey}"
  provisioner "remote-exec" {
    inline = "/usr/bin/sudo /sbin/setenforce 0 && /bin/curl https://raw.githubusercontent.com/ncorrare/terraform-examples/master/provision.sh | /usr/bin/sudo /bin/bash && /usr/bin/sudo /opt/puppetlabs/bin/puppet apply -e 'include profile::consulserver'"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file(var.keypath)}"
    }
  }
}

resource "aws_instance" "database" {
  ami                         = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.vpc_subnet.id}"
  vpc_security_group_ids      = ["${aws_security_group.vpc.id}"]
  associate_public_ip_address = "true"
  key_name                    = "${var.sshkey}"
  provisioner "remote-exec" {
    inline = "/usr/bin/sudo /sbin/setenforce 0 && /bin/curl https://raw.githubusercontent.com/ncorrare/terraform-examples/master/provision.sh | /usr/bin/sudo /bin/bash && sudo /bin/sh -c \"echo 'consulserver: ${aws_instance.consulserver.private_ip}' > /opt/puppetlabs/facter/facts.d/consulserver.yaml\" && /usr/bin/sudo /opt/puppetlabs/bin/puppet apply -e 'include profile::database'"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file(var.keypath)}"
    }
  }
}
