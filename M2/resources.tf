########################################################
#Providers
########################################################
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "us-west-2"
}
########################################################
#Data
########################################################

#pulling all AZ's withing a rigion
data "aws_availability_zones" "available" {
}

########################################################
#Resources
########################################################

#Networking
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "Terraform"
  cidr   = "10.0.0.0/16"

  #slice (list of zones, starting from 0 for example, to..."2" for ex) 
  #.names - returns a list of AZs 
  azs = slice(data.aws_availability_zones.available.names, 0, var.subnet_count)

#ToDo in future we'll generate a custom cidr from the base VPC Cidr. [InCustom Data Sources]
  private_subnets = ["10.0.1.0/24", "10.0.3.0/24","10.0.5.0/24"]
  public_subnets  = ["10.0.0.0/24", "10.0.2.0/24","10.0.4.0/24"]

  enable_nat_gateway           = true
  create_database_subnet_group = false
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
#terraform init --var-file="..\terraform.tfvars"
#terraform plan --var-file="..\terraform.tfvars" -out terraform.tfplan
#terraform apply terraform.tfplan

#https://github.com/ned1313/Deep-Dive-Terraform/tree/master/module2

