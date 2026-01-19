terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "ddau-tfstate-or-client-dot-tst"
    dynamodb_table = "ddau-tfstate-or-client-dot-tst-lock"
    region         = "ap-southeast-2"
    key            = "step_function_resources/tst/terraform.tfstate"
  }

  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.19.0"
    }
    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    #   version = "1.13.1"
    # }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  allowed_account_ids = [
    data.terraform_remote_state.management.outputs.aws_account_id,
    data.terraform_remote_state.environment_setup.outputs.aws_account_id
  ]

  assume_role {
    role_arn = "arn:aws:iam::${data.terraform_remote_state.environment_setup.outputs.aws_account_id}:role/${data.terraform_remote_state.environment_setup.outputs.administratoraccess_trust_role}"
  }

  ignore_tags {
    keys = [
      "APPID",
      "BILLINGCODE",
      "BILLINGCONTACT",
      "BUSINESSAREA",
      "GROUPCONTACT",
      "COUNTRY",
      "CMS",
      "CSCLASS",
      "CSQUAL",
      "CSTYPE",
      "ENVIRONMENT",
      "FUNCTION",
      "MEMBERFIRM",
      "PRIMARYCONTACT",
      "SECONDARYCONTACT",
    ]
  }

  default_tags {
    tags = {
      Product     = "OptimalReality"
      Environment = var.env_prefix
    }
  }
}

module "mm_etl_workflow" {
  source = "../../modules/step_function"

  for_each = local.mm_etl_workflow

  create_eb  = each.value.create_eb
  env_prefix = var.env_prefix
  debug      = var.debug

  # Event Bridge Configuration
  eb_rule_schedule_expression             = each.value.eb_rule_schedule_expression
  eb_rule_schedule_expression_description = each.value.eb_rule_schedule_expression_description

  # Step Function Configuration
  sfn_name                 = each.value.sfn_name
  sfn_definition_file_name = each.value.sfn_definition_file_name
  sfn_definition_prefix    = each.value.sfn_definition_prefix
  sfn_role_arn             = "arn:aws:iam::729234215193:role/MM-StepFunction-Role"
  sfn_service_versions     = local.sfn_service_versions
  sfn_backoff_limit        = each.value.sfn_backoff_limit

  memory_small   = local.memory_small
  memory_medium  = local.memory_medium
  memory_large   = local.memory_large
  memory_xlarge  = local.memory_xlarge
  memory_2xlarge = local.memory_2xlarge
  memory_3xlarge = local.memory_3xlarge
  memory_5xlarge = local.memory_5xlarge
  memory_10xlarge = local.memory_10xlarge
  memory_20xlarge = local.memory_20xlarge
  memory_50xlarge = local.memory_50xlarge

  cpu_small   = local.cpu_small
  cpu_medium  = local.cpu_medium
  cpu_large   = local.cpu_large
  cpu_xlarge  = local.cpu_xlarge
  cpu_2xlarge = local.cpu_2xlarge
  cpu_4xlarge = local.cpu_4xlarge
  cpu_6xlarge = local.cpu_6xlarge
  cpu_8xlarge = local.cpu_8xlarge
  cpu_20xlarge = local.cpu_20xlarge

  # Lambda Configuration
  lambda_name                        = each.value.lambda_name
  lambda_handler                     = each.value.lambda_handler
  lambda_runtime                     = each.value.lambda_runtime
  eks_vpc_subnet_ids                 = local.eks_vpc_subnet_ids
  eks_cluster_vpc_security_group_ids = local.eks_cluster_vpc_security_group_ids
}