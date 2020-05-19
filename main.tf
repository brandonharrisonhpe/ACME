provider "aws" {
  region = "us-west-1"
}

data "aws_availability_zones" "azs" {
  provider = aws
  state = "available"
}

module "vpc" {
 source = "terraform-aws-modules/vpc/aws"

  name = "TFE-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.azs.names
  public_subnets  = ["10.0.101.0/24"]
  private_subnets  = ["10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Environment = "Test"
    Tool = "Terraform"
  }
}

module "tfe" {
  source = "git::git@github.com:hashicorp/terraform-chip-tfe-is-terraform-aws-ptfe-v4-quick-install.git"

  common_tags                = {
    Environment = "Test"
    Tool        = "Terraform"
  }
  friendly_name_prefix       = var.friendly_name_prefix
  tfe_hostname               = var.tfe_hostname
  tfe_license_file_path      = var.tfe_license_file_path
  vpc_id                     = module.vpc.vpc_id
  alb_subnet_ids             = [module.vpc.public_subnets[0]]
  ec2_subnet_ids             = [module.vpc.private_subnets[0]]
  rds_subnet_ids             = [module.vpc.private_subnets[1]]
  route53_hosted_zone_name   = var.route53_hosted_zone_name
}

output "tfe_url" {
  value = module.tfe.tfe_url
}

output "tfe_admin_console_url" {
  value = module.tfe.tfe_admin_console_url
}

