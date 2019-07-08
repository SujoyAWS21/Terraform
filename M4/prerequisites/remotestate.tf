##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_networking_bucket" {
    default = "ddt-networking2310202"
}
variable "aws_application_bucket" {
    default = "ddt-application2310202"
}
variable "aws_dynamodb_table" {
    default = "ddt-tfstatelock"
}
#backend config will look for explicitly defined s3 credentials in the backend config 
#then it will check for aws credentions in aws config user path 
#it will check and path the profile that is defined there 
variable "user_home_path" {}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-west-2"
}

##################################################################################
# RESOURCES
##################################################################################
resource "aws_dynamodb_table" "terraform_statelock" {
  name           = "${var.aws_dynamodb_table}" #(Required) 
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID" #(Required), Case sensitive

  attribute { #(Required) 
    name = "LockID"
    type = "S" #string
  }
}

#Creating bucket for networking
resource "aws_s3_bucket" "ddtnet" {
  bucket = "${var.aws_networking_bucket}"
  acl    = "private"
  force_destroy = true
  
  versioning {
    enabled = true
  }
#Appling policy to bucket that allows AppTeam (Sally Sue) GetObject from the bucket 
#another Policy allows to do all actions on the bucket.
      policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "ReadforAppTeam",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_iam_user.sallysue.arn}"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${var.aws_networking_bucket}/*"
        },
        { 
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_iam_user.marymoe.arn}" 
            },
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${var.aws_networking_bucket}",
                "arn:aws:s3:::${var.aws_networking_bucket}/*"
            ]
        }
    ]
}
EOF
}
#Doing the same thing for the AppBucket
#Marry Moe read only access 
#SallySue RW access 
resource "aws_s3_bucket" "ddtapp" {
  bucket = "${var.aws_application_bucket}"
  acl    = "private"
  force_destroy = true

  versioning {
    enabled = true
  }
        policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "ReadforNetTeam",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_iam_user.marymoe.arn}"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${var.aws_application_bucket}/*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_iam_user.sallysue.arn}"
            },
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${var.aws_application_bucket}",
                "arn:aws:s3:::${var.aws_application_bucket}/*"
            ]
        }
    ]
}
EOF
}
#Creating a user
resource "aws_iam_group" "ec2admin" {
  name = "EC2Admin"
}
#Creating Policy for this user 
resource "aws_iam_group_policy_attachment" "ec2admin-attach" {
  group      = "${aws_iam_group.ec2admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
# Creeating IAM User Sally Sue 
resource "aws_iam_user" "sallysue" {
  name = "sallysue"
}
# Giving RW access to Sally Sue
resource "aws_iam_user_policy" "sallysue_rw" {
    name = "sallysue"
    user = "${aws_iam_user.sallysue.name}"
    policy= <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${var.aws_application_bucket}",
                "arn:aws:s3:::${var.aws_application_bucket}/*"
            ]
        },
                {
            "Effect": "Allow",
            "Action": ["dynamodb:*"],
            "Resource": [
                "${aws_dynamodb_table.terraform_statelock.arn}"
            ]
        }
   ]
}
EOF
}
#MaryMoe
#Creating IAM User Mary Moe
#Access Key for user Mary Moe
#RW Policy to Networking Bucket for MMoe user
#Group Membership
#Dynamo DB Access 
resource "aws_iam_user" "marymoe" {
    name = "marymoe"
}

resource "aws_iam_access_key" "marymoe" {
    user = "${aws_iam_user.marymoe.name}"
}

resource "aws_iam_user_policy" "marymoe_rw" {
    name = "marymoe"
    user = "${aws_iam_user.marymoe.name}"
   policy= <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${var.aws_networking_bucket}",
                "arn:aws:s3:::${var.aws_networking_bucket}/*"
            ]
        },
                {
            "Effect": "Allow",
            "Action": ["dynamodb:*"],
            "Resource": [
                "${aws_dynamodb_table.terraform_statelock.arn}"
            ]
        }
   ]
}
EOF
}
#state-lock
resource "aws_iam_access_key" "sallysue" {
    user = "${aws_iam_user.sallysue.name}"
}

resource "aws_iam_group_membership" "add-ec2admin" {
  name = "add-ec2admin"

  users = [
    "${aws_iam_user.sallysue.name}",
  ]

  group = "${aws_iam_group.ec2admin.name}"
}

#Specilized resource to write into a local file that we specify
#it will be used by backend configurations
resource "local_file" "aws_keys" {
    content = <<EOF
[default]
aws_access_key_id = ${var.aws_access_key}
aws_secret_access_key = ${var.aws_secret_key}

[sallysue]
aws_access_key_id = ${aws_iam_access_key.sallysue.id}
aws_secret_access_key = ${aws_iam_access_key.sallysue.secret}

[marymoe]
aws_access_key_id = ${aws_iam_access_key.marymoe.id}
aws_secret_access_key = ${aws_iam_access_key.marymoe.secret}

EOF
    filename = "${var.user_home_path}/.aws/credentials"

}

##################################################################################
# OUTPUT
##################################################################################
#output "username" {value = "${aws_iam_user.sallysue.name}"}

output "sally-access-key" {
    value = "${aws_iam_access_key.sallysue.id}"
}

output "sally-secret-key" {
    value = "${aws_iam_access_key.sallysue.secret}"
}

output "mary-access-key" {
    value = "${aws_iam_access_key.marymoe.id}"
}

output "mary-secret-key" {
    value = "${aws_iam_access_key.marymoe.secret}"
}