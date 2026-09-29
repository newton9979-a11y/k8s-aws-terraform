variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "nani"
}

variable "ami_id" {
  description = "Ubuntu AMI"
  type        = string
  default     = "ami-006f82a1d5a27da54"
}

variable "key_name" {
  description = "EC2 key pair"
  type        = string
  default     = "Nani-nani_mumbai"
}

variable "security_group_id" {
  description = "Existing security group"
  type        = string
  default     = "sg-033ff956a203e8b19"
}

variable "subnet_id" {
  description = "Subnet where worker instances will be created"
  type        = string
}
