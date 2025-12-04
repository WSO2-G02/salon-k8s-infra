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
  default = 5
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "github_actions_ips" {
  type        = string
  description = "Source IP allowed for SSH access (with /32)"
  default     = "203.0.113.25/32"
}