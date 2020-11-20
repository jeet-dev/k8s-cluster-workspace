provider "aws" {
  region = "us-east-1"
}

variable "availability-zones" {
  default = [
    "us-east-1a"
  ]
  type = list(string)
}


resource "aws_key_pair" "rancher" {
  key_name   = "rancher"
  public_key = file("clusterkeys.pub")
}

variable "rancher_servers" {
	type = list(string)
  default = ["master","worker1","worker2"]
}

resource "aws_security_group" "rancher" {
  name        = "rancher-security-group"
  description = "Allow HTTP, HTTPS and SSH traffic"
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform"
  }
}

resource "aws_instance" "rancher" {
  for_each      = toset(var.rancher_servers)
  key_name      = aws_key_pair.rancher.key_name
  ami           = "ami-0c94855ba95c71c99"
  availability_zone = "us-east-1a"
  instance_type = "t2.medium"
  tags = {
    Name = each.value
  }

  vpc_security_group_ids = [
    aws_security_group.rancher.id
  ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("clusterkeys")
    host        = self.public_ip
  }
  

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install docker -y",
      "sudo service docker start",
      "sudo usermod -a -G docker ec2-user root",
      "sudo chkconfig docker on",
      "sudo yum install -y git",
      "sudo systemctl restart docker",
      "sudo curl -sLS https://get.k3sup.dev | sh",
      "sudo cp k3sup /usr/local/bin/k3sup"	
    ]
  }
}

output "ips_with_list_in_brackets" {
  value = [
    for instance in aws_instance.rancher:
    (instance.public_ip != "" ? [instance.private_ip, instance.public_ip] : [instance.private_ip])
  ]
}

output "instance_private_ip_addresses" {
value = {
for instance in aws_instance.rancher:
instance.id => instance.private_ip
}
}

output "instance_public_ip_addresses" {
value = {
for instance in aws_instance.rancher:
instance.id => instance.public_ip
}
}
