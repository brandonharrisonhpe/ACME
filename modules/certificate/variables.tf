variable "aws_region" {
  type        = string
  description = "Region for AWS deployment"
}

variable "friendly_name_prefix" {
  type        = string
  description = "String value for freindly name prefix for AWS resource names and tags"
}

variable "cname" {
  type        = string
  description = "The CNAME for the certificate"
}

variable "organization" {
  type        = string
  description = "The name for the organization provisioning the certificate"
}

