resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Kubernetes cluster nodes and microservices"

  # SSH for Github Runner
  ingress {
    description     = "SSH from GitHub Runner"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.runner_sg.id]
  }

  # Kubernetes API (6443 TCP)

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kubernetes API (control plane)"
  }

  # VXLAN / Calico IP-in-IP (4789 UDP)

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
    description = "VXLAN for networking"
  }

  # Microservices (8001-8006 TCP)

  ingress {
    from_port       = 8001
    to_port         = 8006
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
    description     = "Microservices ports"
  }

  # NodePort services (30000-32767 TCP)

  ingress {
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
    description     = "Kubernetes NodePort services"
  }

  # ETCD (2379-2380 TCP)

  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "ETCD Database Communication"
  }

  # Kubelet, Scheduler, Controller/Manager (10250-10252 TCP)

  ingress {
    from_port   = 10250
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kubernetes Internal Components"
  }

  # Calico IP-in-IP (all TCP/UDP)  (protocol number 4)

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "4"
    cidr_blocks = [var.vpc_cidr]
    description = "Calico IP-in-IP traffic"
  }

  # BGP (179 TCP)

  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "BGP routing (Calico or other)"
  }

  # HTTP Traffic from LoadBalancers

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_sg.id]
    description     = "HTTP traffic from LoadBalancer"
  }

  # Allow all Outbound 

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  depends_on = [
    aws_vpc.main
  ]

  tags = {
    Name    = "${var.project_name}-k8s-sg"
    Project = var.project_tag
  }

}

resource "aws_security_group" "elb_sg" {
  name   = "${var.project_name}-elb-sg"
  vpc_id = aws_vpc.main.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # public-facing
    description = "HTTP traffic"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr] # allow outbound to nodes
  }

  depends_on = [
    aws_vpc.main
  ]

  tags = {
    Name    = "${var.project_name}-elb-sg"
    Project = var.project_tag
  }

}

# Runner Security grou

resource "aws_security_group" "runner_sg" {
  name        = "${var.project_name}-runner-sg"
  description = "SG for GitHub self-hosted runner"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # For debugging
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_vpc.main
  ]

  tags = {
    Name    = "${var.project_name}-runner-sg"
    Project = var.project_tag
  }

}

