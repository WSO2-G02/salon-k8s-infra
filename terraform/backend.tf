# S3 Bucket for Terraform Stat File

terraform {
  backend "s3" {
    key          = "global/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}



