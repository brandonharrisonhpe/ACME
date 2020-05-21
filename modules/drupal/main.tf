provider "aws" {
  alias = "primary_region"
  region = var.primary_region
}

provider "aws" {
  alias = "replica_region"
  region = var.replica_region
}

locals {
  primary_cidr_block = "10.0.0.0/16"
  replica_cidr_block = "10.1.0.0/16"
}

data "aws_availability_zones" "primary_azs" {
  provider = aws.primary_region
  state = "available"
}

data "aws_availability_zones" "replica_azs" {
  provider = aws.replica_region
  state = "available"
}

module "primary-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "primary-vpc"
  cidr = local.primary_cidr_block

  azs             = data.aws_availability_zones.primary_azs.names

  public_subnets  = [for az in data.aws_availability_zones.primary_azs.names : cidrsubnet(local.primary_cidr_block, 8, index(data.aws_availability_zones.primary_azs.names, az))]

  providers = {
    aws = aws.primary_region
  }
}

module "replica-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "replica-vpc"
  cidr = local.replica_cidr_block

  azs             = data.aws_availability_zones.replica_azs.names

  public_subnets  = [for az in data.aws_availability_zones.replica_azs.names : cidrsubnet(local.replica_cidr_block, 8, index(data.aws_availability_zones.replica_azs.names, az))]

  providers = {
    aws = aws.replica_region
  }
}

resource "aws_vpc_peering_connection" "peer" {
  provider      = aws.primary_region
  vpc_id        = module.primary-vpc.vpc_id
  peer_vpc_id   = module.replica-vpc.vpc_id
  peer_region   = var.primary_region
  auto_accept   = false
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.replica_region
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
}

resource "aws_default_security_group" "primary-vpc" {
  provider = aws.primary_region
  vpc_id   = module.primary-vpc.vpc_id

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_default_security_group" "replica-vpc" {
  provider = aws.replica_region
  vpc_id   = module.replica-vpc.vpc_id

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  primary_routes = setproduct(module.primary-vpc.public_route_table_ids, module.replica-vpc.public_subnets_cidr_blocks)
  replica_routes = setproduct(module.replica-vpc.public_route_table_ids, module.primary-vpc.public_subnets_cidr_blocks)
}

resource "aws_route" "primary-vpc" {
  count = length(local.primary_routes)
  provider                  = aws.primary_region

  route_table_id = element(element(local.primary_routes, count.index), 0)
  destination_cidr_block = element(element(local.primary_routes, count.index), 1)
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "replica-vpc" {
  count = length(local.replica_routes)
  provider                  = aws.replica_region

  route_table_id = element(element(local.replica_routes, count.index), 0)
  destination_cidr_block = element(element(local.replica_routes, count.index), 1)
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# resource "aws_db_instance" "default" {
#   allocated_storage    = 20
#   storage_type         = "gp2"
#   engine               = "mysql"
#   engine_version       = "5.7"
#   instance_class       = "db.t3.medium"
#   name                 = "ebdb"
#   username             = "foo"
#   password             = "foobarbaz"
#   parameter_group_name = "default.mysql5.7"
# }

