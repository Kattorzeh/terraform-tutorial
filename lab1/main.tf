terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30.0"
    }
  }
}

provider "aws" {
    profile= "terraform-up-and-running"
}

resource "aws_instance" "ec2_linux" {
  ami           = var.ami_name
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sec_group_ec2.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "book-example-webserver"
  }
}

resource "aws_security_group" "sec_group_ec2" {
  name = "terrafrom-ec2-sec-group"

  ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }
}

variable "server_port" {
  description = "Port used by the server for HTTP requests"
  type        = number
  default = 8080
}

variable "ami_name" {
  description = "AWS Ubuntu AMI ID"
  type = string
  default = "ami-0fc5d935ebf8bc3bc"
}

output "public_ip_ec2"{
  description = "Public IP of the EC2 instance"
  value = aws_instance.ec2_linux.public_ip
}