output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "master_private_ip" {
  value = aws_instance.master.private_ip
}

output "worker_asg_name" {
  value = aws_autoscaling_group.workers.name
}

output "worker_min_size" {
  value = aws_autoscaling_group.workers.min_size
}

output "worker_desired_size" {
  value = aws_autoscaling_group.workers.desired_capacity
}

output "worker_max_size" {
  value = aws_autoscaling_group.workers.max_size
}
