# Common

variable "env_prefix" {
  description = "AWS Environments Prefix"
  type        = string
}

variable "debug" {
  description = "Debug Mode"
  type = bool
  default = false  
}

#################################################
# Step Function Variables
#################################################

variable "sfn_name" {
  description = "Step Function Name"
  type        = string
}

variable "sfn_definition_file_name" {
  description = "sfn definition file path"
  type        = string
}

variable "sfn_definition_prefix" {
  description = "sfn definition prefix for K8s Job"
  type        = string
}

variable "sfn_role_arn" {
  description = "SFN role arn"
  type        = string
}

variable "sfn_service_versions" {
  description = "Mapping of versions of microservices."
  type        = map(object({
    version  = string
    image     = string
  }))
}

variable "sfn_backoff_limit" {
  description = "SFN Backoff limit"
  type        = number
}

#################################################
# Event Bridge Configuration
#################################################

variable "eb_rule_schedule_expression" {
  description = "Event Bridge Rule Schedule Expression"
  type        = string
}

variable "eb_rule_schedule_expression_description" {
  description = "Event Bridge Rule Schedule Expression Description"
  type        = string
}

variable "create_eb" {
  description = "Condition to create Event Bridge or not"
  type        = bool
  default     = false
}

#################################################
# Lambda Configuration
#################################################
variable "lambda_name" {
  description = "Lambda Name"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda Runtime"
  type        = string
}

variable "lambda_handler" {
  description = "Lambda Handler"
  type        = string
}

variable "eks_vpc_subnet_ids" {
  description = "List of eks vpc subnet ids"
  type        = list(string)
}

variable "eks_cluster_vpc_security_group_ids" {
  description = "List of eks cluster group id"
  type        = list(string)
}

#################################################
# EKS Memory and CPU Configurations
#################################################

variable "cpu_small" {
  description = "cpu_small. Defaults to 200m"
  type        = string
  default     = "200m"
}

variable "cpu_medium" {
  description = "cpu_medium. Defaults to 400m"
  type        = string
  default     = "400m"
}

variable "cpu_large" {
  description = "cpu_large. Defaults to 600m"
  type        = string
  default     = "600m"
}

variable "cpu_xlarge" {
  description = "cpu_xlarge. Defaults to 800m"
  type        = string
  default     = "800m"
}

variable "cpu_2xlarge" {
  description = "cpu_2xlarge. Defaults to 1000m"
  type        = string
  default     = "1000m"
}


variable "cpu_4xlarge" {
  description = "cpu_4xlarge. Defaults to 2000m"
  type        = string
  default     = "2000m"
}

variable "cpu_6xlarge" {
  description = "cpu_6xlarge. Defaults to 3000m"
  type        = string
  default     = "3000m"
}

variable "cpu_8xlarge" {
  description = "cpu_8xlarge. Defaults to 4000m"
  type        = string
  default     = "4000m"
}

variable "cpu_20xlarge" {
  description = "cpu_20xlarge. Defaults to 10000m"
  type        = string
  default     = "10000m"
}

variable "memory_small" {
  description = "memory_small. Defaults to 400Mi"
  type        = string
  default     = "400Mi"
}

variable "memory_medium" {
  description = "memory_medium. Defaults to 700Mi"
  type        = string
  default     = "700Mi"
}

variable "memory_large" {
  description = "memory_large. Defaults to 1Gi"
  type        = string
  default     = "1Gi"
}

variable "memory_xlarge" {
  description = "cpu_xlarge. Defaults to 1.3Gi"
  type        = string
  default     = "1.3Gi"
}

variable "memory_2xlarge" {
  description = "memory_2xlarge. Defaults to 1.6Gi"
  type        = string
  default     = "1.6Gi"
}

variable "memory_3xlarge" {
  description = "memory_3xlarge. Defaults to 2Gi"
  type        = string
  default     = "2Gi"
}

variable "memory_5xlarge" {
  description = "memory_3xlarge. Defaults to 2Gi"
  type        = string
  default     = "2Gi"
}

variable "memory_10xlarge" {
  description = "memory_10xlarge. Defaults to 10Gi"
  type        = string
  default     = "10Gi"
}

variable "memory_20xlarge" {
  description = "memory_20xlarge. Defaults to 20Gi"
  type        = string
  default     = "20Gi"
}

variable "memory_30xlarge" {
  description = "memory_30xlarge. Defaults to 30Gi"
  type        = string
  default     = "30Gi"
}

variable "memory_50xlarge" {
  description = "memory_50xlarge. Defaults to 50Gi"
  type        = string
  default     = "50Gi"
}
