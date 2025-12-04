terraform {
  backend "s3" {
    bucket       = "salon-terraform-state10249343"
    key          = "global/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
