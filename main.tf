terraform {
  #############################################################
  ## AFTER RUNNING TERRAFORM APPLY (WITH LOCAL BACKEND)
  ## YOU WILL UNCOMMENT THIS CODE THEN RERUN TERRAFORM INIT
  ## TO SWITCH FROM LOCAL BACKEND TO REMOTE AWS BACKEND
  #############################################################
  #  backend "s3" {
  #    bucket         = "django-tf-state"
  #    key            = "/django/terraform.tfstate"
  #    region         = var.region
  #    dynamodb_table = "terraform-state-locking"
  #    encrypt        = true
  #  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Bucket to store the Terraform state file:
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "devops-terraform-statefile-web-app"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "terraform_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_crypto_conf" {
  bucket = aws_s3_bucket.terraform_state.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# Define user data script as a variable
variable "user_data_script" {
  default = <<-EOF
              #!/bin/bash
              sudo yum -y install python-pip
              wget https://github.com/ZakriaG/FitnessLog/archive/refs/heads/main.zip
              unzip main.zip
              cd FitnessLog-main
              pip install -r requirements.txt -I
              export HOST_IP="$(hostname -I | tr -d ' \t\n\r')"
              python3 manage.py runserver 0.0.0.0:8000
              EOF
}

# Instances to run the django web app:
resource "aws_instance" "django_app_instance" {
  count           = 2
  ami             = var.ami
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instances.name]
  user_data       = var.user_data_script
  tags = {
    Name = "django_app_instance_${count.index + 1}"
  }
}

  #############################################################
  ## To demonstrate the second instance is used by the
  ## load balancer uncomment the following:
  #############################################################
  #  user_data       = <<-EOF
  #              #!/bin/bash
  #              echo "EC2 instance 2!" > index.html
  #              python3 -m http.server 8000 &
  #              EOF
}

# Virtual Private Cloud:
data "aws_vpc" "default_vpc" {
  default = true
}

# Subnet
data "aws_subnet_ids" "default_subnet" {
  vpc_id = data.aws_vpc.default_vpc.id
}

# Security Group
resource "aws_security_group" "instances" {
  name = "instance-security-group"
}

# EC2 Security Group Rules:
resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 8000
  to_port     = 8000
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "allow_http_outbound" {
  # If the EC2 needs to download from the internet.
  # In this project it needs to download python packages and a Git repository.
  type              = "egress"
  security_group_id = aws_security_group.instances.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

# Load Balancer Listener:

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn

  port = 80

  protocol = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}


resource "aws_lb_target_group" "instances" {
  name     = "example-target-group"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "django_instance_1" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.django_app_instance[0].id
  port             = 8000
}

resource "aws_lb_target_group_attachment" "django_instance_2" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.django_app_instance[1].id
  port             = 8000
}

resource "aws_lb_listener_rule" "django_instances" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }
}


resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

# Inbound Rules:
resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Outbound Rules:
resource "aws_security_group_rule" "allow_alb_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

}

# Load Balancer
resource "aws_lb" "load_balancer" {
  name               = "django-web-app-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default_subnet.ids
  security_groups    = [aws_security_group.alb.id]

}

#resource "aws_route53_zone" "primary" {
#  name = "example.com"
#}
#
#resource "aws_route53_record" "root" {
#  zone_id = aws_route53_zone.primary.zone_id
#  name    = "example.com"
#  type    = "A"
#
#  alias {
#    name                   = aws_lb.load_balancer.dns_name
#    zone_id                = aws_lb.load_balancer.zone_id
#    evaluate_target_health = true
#  }
#}
#
