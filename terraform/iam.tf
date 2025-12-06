# Uses Existing IAM role
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.project_name}-ssm-instance-profile"
  role = var.ssm_role_name
}