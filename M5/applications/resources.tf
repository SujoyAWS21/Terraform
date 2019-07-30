#Based on the work from https://github.com/arbabnazar/terraform-ansible-aws-vpc-ha-wordpress

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  profile = var.aws_profile
  region  = "us-west-2"
}

##################################################################################
# RESOURCES
##################################################################################

resource "aws_launch_configuration" "webapp_lc" {
  lifecycle {
    create_before_destroy = true
  }

  name_prefix   = "${terraform.workspace}-ddt-lc-"
  image_id      = data.aws_ami.aws_linux.id
  instance_type = data.external.configuration.result.asg_instance_size

  #SG's defined in a separate configuration file
  security_groups = [
    aws_security_group.webapp_http_inbound_sg.id,
    aws_security_group.webapp_ssh_inbound_sg.id,
    aws_security_group.webapp_outbound_sg.id,
  ]

  user_data                   = file("./templates/userdata.sh") #passing userdata for some basic configuration (ex: installing NGINX)
  key_name                    = var.key_name                    #ssh key that will be used to login to the instance
  associate_public_ip_address = true
}

#Creating ELB
resource "aws_elb" "webapp_elb" {
  name = "ddt-webapp-elb"
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibilty in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  subnets = [data.terraform_remote_state.networking.outputs.public_subnets] #pulling network list from networking

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }

  security_groups = [aws_security_group.webapp_http_inbound_sg.id] # SG for ELB, allow port 80 for inbound traffic

  tags = local.common_tags
}

#creating ASG
resource "aws_autoscaling_group" "webapp_asg" {
  lifecycle {
    create_before_destroy = true
  }

  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibilty in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  vpc_zone_identifier   = [data.terraform_remote_state.networking.outputs.public_subnets]
  name                  = "ddt_webapp_asg"
  max_size              = data.external.configuration.result.asg_max_size
  min_size              = data.external.configuration.result.asg_min_size
  //wait_for_elb_capacity = false
  force_delete          = true
  launch_configuration  = aws_launch_configuration.webapp_lc.id
  load_balancers        = [aws_elb.webapp_elb.name]

  tags = [
    {
      "key"                 = "Name"
      "value"               = "ddt_webapp_asg"
      "propagate_at_launch" = true
    },
    {
      "key"                 = "environment"
      "value"               = data.external.configuration.result.environment
      "propagate_at_launch" = true
    },
    {
      "key"                 = "billing_code"
      "value"               = data.external.configuration.result.billing_code
      "propagate_at_launch" = true
    },
    {
      "key"                 = "project_code"
      "value"               = data.external.configuration.result.project_code
      "propagate_at_launch" = true
    },
    {
      "key"                 = "network_lead"
      "value"               = data.external.configuration.result.network_lead
      "propagate_at_launch" = true
    },
    {
      "key"                 = "application_lead"
      "value"               = data.external.configuration.result.application_lead
      "propagate_at_launch" = true
    },
  ]
}

#
# Scale Up Policy and Alarm
#
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "ddt_asg_scale_up"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name                = "ddt-high-asg-cpu"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  insufficient_data_actions = []

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }

  alarm_description = "EC2 CPU Utilization"
  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]
}

#
# Scale Down Policy and Alarm
#
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "ddt_asg_scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 600
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name                = "ddt-low-asg-cpu"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "5"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "30"
  insufficient_data_actions = []

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }

  alarm_description = "EC2 CPU Utilization"
  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.aws_linux.id
  instance_type = data.external.configuration.result.asg_instance_size
  subnet_id = element(
    data.terraform_remote_state.networking.outputs.public_subnets,
    0,
  )
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion_ssh_sg.id]
  key_name                    = var.key_name

  tags = merge(
    local.common_tags,
    {
      "Name" = "ddt_bastion_host"
    },
  )
}

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  vpc      = true
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name = "${terraform.workspace}-ddt-rds-subnet-group"
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibilty in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  subnet_ids = [data.terraform_remote_state.networking.outputs.private_subnets]
}

#Setting up RDS
resource "aws_db_instance" "rds" {
  identifier             = "${terraform.workspace}-ddt-rds"
  allocated_storage      = data.external.configuration.result.rds_storage_size
  engine                 = data.external.configuration.result.rds_engine
  engine_version         = data.external.configuration.result.rds_version
  instance_class         = data.external.configuration.result.rds_instance_size
  multi_az               = data.external.configuration.result.rds_multi_az
  name                   = "${terraform.workspace}${data.external.configuration.result.rds_db_name}"
  username               = var.rds_username
  password               = var.rds_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  tags = local.common_tags
}

