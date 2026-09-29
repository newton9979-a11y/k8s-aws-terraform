terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.54.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ---------------------------------------------------------
# MASTER NODE
# ---------------------------------------------------------

resource "aws_instance" "master" {
  ami                         = var.ami_id
  instance_type               = "t3.medium"
  key_name                    = var.key_name
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true

  user_data = file("${path.module}/scripts/master.sh")

  tags = {
    Name = "K8s-Master-Node"
    Role = "master"
  }
}

# ---------------------------------------------------------
# IAM ROLE FOR WORKER CLOUDWATCH AGENT
# ---------------------------------------------------------

resource "aws_iam_role" "worker_role" {
  name = "k8s-worker-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ---------------------------------------------------------
# CLOUDWATCH AGENT POLICY
# ---------------------------------------------------------

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ---------------------------------------------------------
# INSTANCE PROFILE
# ---------------------------------------------------------

resource "aws_iam_instance_profile" "worker_profile" {
  name = "k8s-worker-cloudwatch-profile"
  role = aws_iam_role.worker_role.name
}

# ---------------------------------------------------------
# LAUNCH TEMPLATE
# ---------------------------------------------------------

resource "aws_launch_template" "worker" {

  name_prefix = "k8s-worker-"

  image_id = var.ami_id

  instance_type = "t3.micro"

  key_name = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true

    security_groups = [
      var.security_group_id
    ]
  }

  user_data = base64encode(
    file("${path.module}/scripts/worker.sh")
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "K8s-Worker"
      Role = "worker"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------
# AUTO SCALING GROUP
# ---------------------------------------------------------

resource "aws_autoscaling_group" "workers" {

  name = "k8s-worker-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 5

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  # IMPORTANT:
  # Replace this subnet ID with your subnet.
  vpc_zone_identifier = [
    var.subnet_id
  ]

  health_check_type = "EC2"

  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "K8s-Worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [
      desired_capacity
    ]
  }
}

# ---------------------------------------------------------
# CPU SCALE OUT
# ---------------------------------------------------------

resource "aws_autoscaling_policy" "scale_out_cpu" {

  name                   = "worker-scale-out-cpu"
  autoscaling_group_name = aws_autoscaling_group.workers.name

  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70
  }
}

# ---------------------------------------------------------
# CPU SCALE IN
# ---------------------------------------------------------

resource "aws_autoscaling_policy" "scale_in_cpu" {

  name                   = "worker-scale-in-cpu"
  autoscaling_group_name = aws_autoscaling_group.workers.name

  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 30
  }
}

# ---------------------------------------------------------
# CLOUDWATCH MEMORY ALARM
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "worker_memory_high" {

  alarm_name = "k8s-worker-memory-high"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2

  metric_name = "mem_used_percent"

  namespace = "CWAgent"

  period = 60

  statistic = "Average"

  threshold = 80

  alarm_description = "Worker memory utilization above 80%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.workers.name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_autoscaling_policy.scale_out_memory.arn
  ]
}

# ---------------------------------------------------------
# MEMORY SCALE OUT
# ---------------------------------------------------------

resource "aws_autoscaling_policy" "scale_out_memory" {

  name                   = "worker-scale-out-memory"

  autoscaling_group_name = aws_autoscaling_group.workers.name

  adjustment_type = "ChangeInCapacity"

  policy_type = "SimpleScaling"

  scaling_adjustment = 1

  cooldown = 300
}

# ---------------------------------------------------------
# MEMORY SCALE IN
# ---------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "worker_memory_low" {

  alarm_name = "k8s-worker-memory-low"

  comparison_operator = "LessThanThreshold"

  evaluation_periods = 5

  metric_name = "mem_used_percent"

  namespace = "CWAgent"

  period = 60

  statistic = "Average"

  threshold = 30

  alarm_description = "Worker memory utilization below 30%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.workers.name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [
    aws_autoscaling_policy.scale_in_memory.arn
  ]
}

resource "aws_autoscaling_policy" "scale_in_memory" {

  name = "worker-scale-in-memory"

  autoscaling_group_name = aws_autoscaling_group.workers.name

  adjustment_type = "ChangeInCapacity"

  policy_type = "SimpleScaling"

  scaling_adjustment = -1

  cooldown = 300
}
