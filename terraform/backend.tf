# S3 Bucket for State File

terraform {
  backend "s3" {
    bucket       = var.bucket_name
    key          = "global/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
