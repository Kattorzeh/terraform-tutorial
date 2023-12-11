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

# Default AWS VPC
data "aws_vpc" "default"{
    default = true
}

# Subnets in this Defautl AWS VPC
data "aws_subnets" "default"{
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

# AWS Application Load Balancer 
resource "aws_lb" "alb" {
  name               = "terraform-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sec_group_alb.id]
  subnets            = data.aws_subnets.default.ids
}

# Listener (listens on specific port and protocol)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  # Fixed-response Action
  default_action {
    type           = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: not found (fixed response content)"
      status_code  = "404"
    }
  }
}

# Listener Rule (send those that match specific paths or hostnames)
resource "aws_lb_listener_rule" "alb-ruler" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100 

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-targets.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

# Target Group (receive requests from the LB)
resource "aws_lb_target_group" "alb-targets" {
  name      = "terrafrom-alb-example"
  port      = var.server_port
  protocol  = "HTTP"
  vpc_id    = data.aws_vpc.default.id
  # Periodically send HTTP request to each instance to check their healthy
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             =  "200"
    interval            = 15
    timeout             = 3 
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# AWS AutoScaling Group (contains a collection of EC2 Instaces)
resource "aws_autoscaling_group" "asg" {
  name     = "asg1-test"
  max_size = 5
  min_size = 2
  # Use target group's health check & lists to ALB the EC2 instances
  target_group_arns = [aws_lb_target_group.alb-targets.arn]
  health_check_type = "ELB"
  # Configuration for Deployiong EC2 in the Default AWS VPC
  launch_configuration = aws_launch_configuration.asg_launch.name
  vpc_zone_identifier  = data.aws_subnets.default.ids
  # EC2 Instances name
  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

#AWS Launch Configuration 8enables ASG launch EC2 Instances)
resource "aws_launch_configuration" "asg_launch" {
  name_prefix        = "terraform-lc-"
  image_id           = var.ami_name
  instance_type      = "t2.micro"

  security_groups    = [aws_security_group.sec_group_ec2.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  # Required in ASG
  lifecycle {
    create_before_destroy = true
  }
}

# AWS Security Group used by EC2 instances
resource "aws_security_group" "sec_group_ec2" {
  name = "terrafrom-ec2-sec-group"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }
}

# AWS Security Group used by ALB instances
resource "aws_security_group" "sec_group_alb" {
  name          = "terrafrom-alb-sec-group"
  # Allow Inbound HTTP requests
  ingress {
    from_port   = var.load_port_http
    to_port     = var.load_port_http
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }
  # Allow all Outbound request (allow LB health checks)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  
  }
}

variable "load_port_http"{
  description = "Port used by the load balancer (ALB)"
  type        = number
  default     = 80
}
variable "server_port" {
  description = "Port used by the server for HTTP requests"
  type        = number
  default     = 8080
}

variable "ami_name" {
  description = "AWS Ubuntu AMI ID"
  type        = string
  default     = "ami-0fc5d935ebf8bc3bc"
}

output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "DNS name of the ALB"
}