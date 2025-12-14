data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --------------------------
# Control Plane Resources
# --------------------------
resource "aws_launch_template" "cp_lt" {
  name_prefix   = "${var.project_name}-cp-lt"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.control_plane_instance_type
  key_name      = aws_key_pair.salon_key.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data = filebase64("user_data.sh")

  depends_on = [
    aws_route_table.public,
    aws_security_group.elb_sg,
    aws_security_group.ec2_sg,
    aws_iam_instance_profile.ec2_profile
  ]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Project = var.project_tag
      Role    = "k8s-control-plane"
      Name    = "${var.project_name}-control-plane"
    }
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = var.control_plane_volume_size
      volume_type = "gp3"
    }
  }
}

resource "aws_autoscaling_group" "cp_asg" {
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]

  launch_template {
    id      = aws_launch_template.cp_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Project"
    value               = var.project_tag
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-control-plane"
    propagate_at_launch = true
  }
}

# --------------------------
# Worker Node Resources
# --------------------------
resource "aws_launch_template" "worker_lt" {
  name_prefix   = "${var.project_name}-worker-lt"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.salon_key.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data = filebase64("user_data.sh")

  depends_on = [
    aws_route_table.public,
    aws_security_group.elb_sg,
    aws_security_group.ec2_sg,
    aws_iam_instance_profile.ec2_profile
  ]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Project = var.project_tag
      Role    = "k8s-worker"
      Name    = "${var.project_name}-worker"
    }
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = var.worker_volume_size
      volume_type = "gp3"
    }
  }
}


resource "aws_autoscaling_group" "worker_asg" {
  # We subtract 1 for the control plane
  desired_capacity    = var.desired_capacity - 1
  min_size            = var.min_size - 1
  max_size            = var.max_size - 1
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]

  launch_template {
    id      = aws_launch_template.worker_lt.id
    version = "$Latest"
  }

  depends_on = [
    aws_route_table.public,
    aws_security_group.elb_sg,
    aws_security_group.ec2_sg,
    aws_launch_template.worker_lt
  ]

  tag {
    key                 = "Project"
    value               = var.project_tag
    propagate_at_launch = true
  }

  health_check_type         = "ELB"
  health_check_grace_period = 600
  min_elb_capacity          = 0
  default_cooldown          = 300
}

data "aws_instances" "cp_instances" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.cp_asg.name]
  }
  instance_state_names = ["running"]
  depends_on = [aws_autoscaling_group.cp_asg]
}

data "aws_instances" "worker_instances" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.worker_asg.name]
  }
  instance_state_names = ["running"]
  depends_on = [aws_autoscaling_group.worker_asg]
}

# Wait for instances to be fully initialized before running Ansible
resource "null_resource" "wait_for_instances" {
  depends_on = [data.aws_instances.cp_instances, data.aws_instances.worker_instances]

  provisioner "local-exec" {
    command = "echo 'Waiting 180 seconds for EC2 instances to initialize...' && sleep 180"
  }

  triggers = {
    cp_ids     = join(",", data.aws_instances.cp_instances.ids)
    worker_ids = join(",", data.aws_instances.worker_instances.ids)
  }
}

resource "null_resource" "generate_inventory" {
  depends_on = [null_resource.wait_for_instances]

  provisioner "local-exec" {
    command     = "bash generate_inventory.sh"
    working_dir = path.module
  }

  triggers = {
    cp_ids     = join(",", data.aws_instances.cp_instances.ids)
    worker_ids = join(",", data.aws_instances.worker_instances.ids)
  }
}