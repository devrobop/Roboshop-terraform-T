terraform {
  backend "s3" {
    bucket = "devrobop-s6"
    key    = "roboshop-tf-state/dev/terraform.tfstate"
    region = "us-east-1"
  }
}