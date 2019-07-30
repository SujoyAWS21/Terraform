##########################
#Backend
#https://www.terraform.io/docs/configuration/terraform.html
##########################
terraform {
  backend "s3" {
    key    = "networking.state"
    region = "us-west-2"
  }
}

