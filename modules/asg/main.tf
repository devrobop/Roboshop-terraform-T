resource "aws_security_group" "main" {
  name        = "${var.name}-${var.env}-sg"
  description = "${var.name}-${var.env}-sg"
  vpc_id      = var.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = var.bastion_nodes
  }

  ingress {
    from_port   = var.allow_port
    to_port     = var.allow_port
    protocol    = "TCP"
    cidr_blocks = var.allow_sg_cidr
  }

  tags = {
    Name = "${var.name}-${var.env}-sg"
  }
}

resource "aws_launch_template" "main" {
  name                   = "${var.name}-${var.env}-lt"
  image_id               = data.aws_ami.rhel9.image_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.main.id]


  instance_market_options {
    market_type = "spot"
  }



  block_device_mappings {
    device_name = "/dev/sda1"
      ebs {
      volume_size = 30
    }
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    env         = var.env
    role_name   = var.name
    app_name    = var.name 
    vault_token = var.vault_token
  }))

  tags = {
    Name = "${var.name}-${var.env}-sg"
  }
}

resource "aws_autoscaling_group" "main" {
  name                = "${var.name}-${var.env}-asg"
  desired_capacity    = var.capacity["desired"]
  max_size            = var.capacity["max"]
  min_size            = var.capacity["min"]
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.main.arn]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "${var.name}-${var.env}"
  }
}


resource "aws_lb_target_group" "main" {
  name     = "${var.name}-${var.env}"
  port     = var.allow_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 5
    path                = "/health"
    timeout             = 3
  }

}

resource "aws_route53_record" "lb" {
  zone_id = var.zone_id
  name    = "${var.name}.${var.env}"
  type    = "CNAME"
  ttl     = 10
  records = [var.dns_name]
}

resource "aws_lb_listener_rule" "listener-rule" {
  listener_arn = var.listener_arn
  priority     = var.lb_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [aws_route53_record.lb.name]
    }
  }
}