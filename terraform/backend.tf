terraform {
  backend "s3" {
    bucket         = "salon-terraform-state10249342"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
