# Top level variables
variable "aws_region" {
  description = "Region to provision this template into"
}

variable "aws_profile" {
  description = "Client AWS profile in which resources will be created"
}

variable "env_prefix" {
  description = "AWS Environments Prefix"
  type        = string
}

variable "management_s3_bucket_name" {
  description = "Name of the management s3 bucket with core install files"
}

variable "environment_s3_bucket_name" {
  description = "Name of the environment-specific s3 bucket with environment state files"
}

variable "debug" {
  description = "Debug Mode"
  type        = bool
  default     = false
}