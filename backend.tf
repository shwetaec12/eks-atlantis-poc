terraform {
  backend "s3" {
    bucket = "poc-terraform-state-bucket-eucentral1"
    key    = "poc/env/terraform.tfstate"
    region = "eu-central-1"
  }
}
