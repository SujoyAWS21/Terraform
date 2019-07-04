############################
#Variables
############################
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}

variable "subnet_count" {
  default = 2
}
variable "bucket_name"{}
variable "environment_tag" {}
variable "billing_code_tag" {}


