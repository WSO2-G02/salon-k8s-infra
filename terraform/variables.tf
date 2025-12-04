variable "region" {
  type    = string
  default = "eu-north-1" # replace as necessary
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
  default = "172.31.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["172.31.1.0/24", "172.31.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["172.31.10.0/24", "172.31.11.0/24"]
}

# List of Microservices

variable "services" {
  type    = list(string)
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
  default = "t3.micro"
}

variable "ami_id" {
  type    = string
  description = "AMI ID for EC2 instances"
}
