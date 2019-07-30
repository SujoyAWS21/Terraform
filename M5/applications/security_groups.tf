##################################################################################
# RESOURCES
##################################################################################

resource "aws_security_group" "bastion_ssh_sg" {
  name        = "bastion_ssh"
  description = "Allow SSH to Bastion host from approved ranges"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ip_range]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "terraform_bastion_ssh"
  }
}

resource "aws_security_group" "nat" {
  name        = "vpc_nat"
  description = "Allow traffic to pass from the private subnet to the internet"

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibilty in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    cidr_blocks = [data.terraform_remote_state.networking.outputs.private_subnets_cidr_blocks]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibilty in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    cidr_blocks = [data.terraform_remote_state.networking.outputs.private_subnets_cidr_blocks]
  }

  ingress {
    from_port = -1
    to_port   = -1
    protocol  = "icmp"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibilty in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    cidr_blocks = [data.terraform_remote_state.networking.outputs.private_subnets_cidr_blocks]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "terraform"
  }
}

resource "aws_security_group" "web_access_from_nat_sg" {
  name        = "private_subnet_web_access"
  description = "Allow web access to the private subnet from the public subnet (via NAT instance)"

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibilty in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    cidr_blocks = [data.terraform_remote_state.networking.outputs.public_subnets_cidr_blocks]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibilty in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    cidr_blocks = [data.terraform_remote_state.networking.outputs.public_subnets_cidr_blocks]
  }

  ingress {
    from_port = -1
    to_port   = -1
    protocol  = "icmp"
    # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
    # force an interpolation expression to be interpreted as a list by wrapping it
    # in an extra set of list brackets. That form was supported for compatibilty in
    # v0.11, but is no longer supported in Terraform v0.12.
    #
    # If the expression in the following list itself returns a list, remove the
    # brackets to avoid interpretation as a list of lists. If the expression
    # returns a single list item then leave it as-is and remove this TODO comment.
    cidr_blocks = [data.terraform_remote_state.networking.outputs.public_subnets_cidr_blocks]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "terraform"
  }
}

resource "aws_security_group" "webapp_http_inbound_sg" {
  name        = "demo_webapp_http_inbound"
  description = "Allow HTTP from Anywhere"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "terraform_demo_webapp_http_inbound"
  }
}

resource "aws_security_group" "webapp_ssh_inbound_sg" {
  name        = "demo_webapp_ssh_inbound"
  description = "Allow SSH from certain ranges"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ip_range]
  }

  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "terraform_demo_webapp_ssh_inbound"
  }
}

resource "aws_security_group" "webapp_outbound_sg" {
  name        = "demo_webapp_outbound"
  description = "Allow outbound connections"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "terraform_demo_webapp_outbound"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "demo_rds_inbound"
  description = "Allow inbound from web tier"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "demo_rds_inbound"
  }

  // allows traffic from the SG itself
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  // allow traffic for TCP 3306
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.webapp_http_inbound_sg.id]
  }

  // outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

