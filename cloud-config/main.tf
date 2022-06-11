terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

locals {
  subnets = slice(data.aws_subnets.default.ids, 0, 2)
}

provider "aws" {
  region = "us-east-2"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ssm_parameter" "python_app_ami" {
  name = "/images/python-application/dev"
}

resource "aws_security_group" "web_server" {
  vpc_id = data.aws_vpc.default.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol    = "ALL"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol         = "ALL"
    from_port        = 0
    to_port          = 0
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_launch_template" "python_app" {
  name          = "python-application"
  image_id      = data.aws_ssm_parameter.python_app_ami.value
  instance_type = "t3.nano"

  vpc_security_group_ids = [aws_security_group.web_server.id]

  # key_name = "nick-desktop.homelab.somemissing.info-ed25519"

  iam_instance_profile {
    name = "AmazonSSMManagedInstanceCore"
  }

  instance_market_options {
    market_type = "spot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "python_app" {
  name_prefix = "pyapp-"
  port        = 80
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    enabled             = true
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "python_app" {
  name               = "python-app"
  internal           = false
  load_balancer_type = "network"
  subnets            = local.subnets

  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.python_app.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.python_app.arn
  }
}

resource "aws_autoscaling_group" "python_app" {
  name_prefix = "python-application-"

  launch_template {
    id      = aws_launch_template.python_app.id
    version = "$Latest"
  }

  min_size         = 1
  desired_capacity = 4
  max_size         = 4

  health_check_type         = "ELB"
  health_check_grace_period = 120
  target_group_arns         = [aws_lb_target_group.python_app.arn]

  vpc_zone_identifier = local.subnets

  lifecycle {
    create_before_destroy = true
  }
}