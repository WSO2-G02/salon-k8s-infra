resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.project_name}-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = filebase64("user_data.sh")

  depends_on = [
    aws_route_table.public,
    aws_security_group.elb_sg,
    aws_security_group.ec2_sg,
    aws_iam_role.ssm_ec2_role,
    aws_iam_role_policy_attachment.ssm_core,
    aws_iam_role_policy_attachment.ecr_read
  ]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Project = var.project_tag
      Role    = "k8s-node"
      Name    = "${var.project_name}-instance"
    }
  }

}


resource "aws_autoscaling_group" "app_asg" {
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }


  depends_on = [
    aws_route_table.public,
    aws_security_group.elb_sg,
    aws_security_group.ec2_sg,
    aws_iam_role.ssm_ec2_role,
    aws_iam_role_policy_attachment.ssm_core,
    aws_iam_role_policy_attachment.ecr_read
  ]

  tag {
    key                 = "Project"
    value               = var.project_tag
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
}
