terraform {
  backend "s3" {
    bucket  = "salon-terraform-state10249343"
    key     = "global/terraform_us_east_1.tfstate"
    region  = "ap-south-1"
    encrypt = true
  }
}
