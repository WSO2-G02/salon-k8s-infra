variable "region" {
  type    = string
  default = "ap-south-1" # replace as necessary
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
  default = "t3.large"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for EC2 instances"
  default     = "ami-0ade68f094cc81635"
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
  default = 4
}

# Reference an existing instance profile
variable "ssm_instance_profile_name" {
  type        = string
  description = "The name of the instance profile used to access EC2 instances"
  default     = "salon-app-ssm-ec2-role"
}

variable "github_repo" {
  description = "GitHub repo in owner/repo format"
  default     = "WSO2-G02/salon-k8s-infra"
}

variable "runner_token" {
  description = "GitHub Actions registration token"
  sensitive   = true
}

variable "gh_runner_version" {
  description = "GitHub Actions Runner Version"
  default     = "2.317.0"
}