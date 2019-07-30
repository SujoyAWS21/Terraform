locals {
  #local variables, we use for reference. kind of a map
  common_tags = {
    environment      = data.external.configuration.result.environment
    billing_code     = data.external.configuration.result.billing_code
    project_code     = data.external.configuration.result.project_code
    network_lead     = data.external.configuration.result.network_lead
    application_lead = data.external.configuration.result.application_lead
  } #stored in the result from external configuration 
}

data "template_file" "public_cidrsubnet" {
  count = data.external.configuration.result.vpc_subnet_count #taking what we know from external configuration (how many subnets exist)

  template = "$${cidrsubnet(vpc_cidr,8,current_count)}" #slicing VPC to automate creation of subnet

  vars = {
    vpc_cidr      = data.external.configuration.result.vpc_cidr_range # getting existing CIDR
    current_count = count.index * 2 + 1                               #Public subnet will be odd in our case, private=even.
  }
}

#Proper Ip addressing for public and private subnets. 
data "template_file" "private_cidrsubnet" {
  count = data.external.configuration.result.vpc_subnet_count #from external configuration we know hoa many subnets should exist. That's the count

  template = "$${cidrsubnet(vpc_cidr,8,current_count)}" #inline template, we slicing subnets and creating a subnet here. 

  vars = {
    vpc_cidr      = data.external.configuration.result.vpc_cidr_range
    current_count = count.index * 2 # private=even.
  }
}

# a lot of data sources relly on
data "external" "configuration" {
  program = ["powershell.exe", "../scripts/getenvironment.ps1"] #passing script

  # in web request. Optional request headers
  # passing some values 
  query = {
    workspace   = terraform.workspace # what worspace are we in dev/prod etc 
    projectcode = var.projectcode     # projectcode+worskapce to query dynamodb table for info
    url         = var.url             # url of the frontside of the API GW to send request to get the information
  }
}

