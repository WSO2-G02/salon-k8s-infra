variable "region" {
  type    = string
  default = "us-east-1" # replace as necessary
}

variable "project_name" {
  type    = string
  default = "salon-app"
}

variable "project_tag" {
  type    = string
  default = "salon-booking-system"
}

# VPC and Subnet variables

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

# List of Microservices

variable "services" {
  type = list(string)
  default = [
    "user_service",
    "appointment_service",
    "service_management",
    "staff_management",
    "notification_service",
    "reports_analytics",
    "frontend"
  ]
}

variable "instance_type" {
  type    = string
  description = "Instance type for worker nodes"
  default = "t3.large"
}

variable "control_plane_instance_type" {
  type    = string
  description = "Instance type for the control plane node"
  default     = "t3.2xlarge"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for EC2 instances (now unused, using data source)"
  default     = ""
}

# Autoscaling variables

variable "min_size" {
  type    = number
  default = 3
}

variable "max_size" {
  type    = number
  default = 6
}

variable "desired_capacity" {
  type    = number
  description = "Total number of nodes (1 CP + N workers). So for 4 total, we launch 1 CP and 3 workers."
  default = 4
}

# Reference an existing instance profile
variable "ssm_instance_profile_name" {
  type        = string
  description = "The name of the instance profile used to access EC2 instances"
  default     = "salon-app-ssm-ec2-role"
}