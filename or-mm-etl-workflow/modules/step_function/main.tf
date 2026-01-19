locals {
  # eb_rule_name = "${var.env_prefix}_${var.eb_rule_name}"
  sfn_name            = "${var.env_prefix}_${var.sfn_name}"
  sfn_definition_path = "${path.module}/definitions/${var.sfn_definition_file_name}"
  lambda_name         = "${var.env_prefix}_${var.lambda_name}"

  sfn_definition_vars_common = {
    lambda_function_arn            = module.lambda_function.lambda_function_arn,
    namespace                      = "${var.env_prefix}-1-batch",
    env_prefix                     = "${var.env_prefix}-1",
    memory_small                   = var.memory_small,
    memory_medium                  = var.memory_medium,
    memory_large                   = var.memory_large,
    memory_xlarge                  = var.memory_xlarge,
    memory_2xlarge                 = var.memory_2xlarge,
    memory_3xlarge                 = var.memory_3xlarge,
    memory_5xlarge                 = var.memory_5xlarge,
    memory_10xlarge                = var.memory_10xlarge,
    memory_20xlarge                = var.memory_20xlarge,
    memory_30xlarge                = var.memory_30xlarge,
    memory_50xlarge                = var.memory_50xlarge,
    cpu_small                      = var.cpu_small,
    cpu_medium                     = var.cpu_medium,
    cpu_large                      = var.cpu_large,
    cpu_xlarge                     = var.cpu_xlarge,
    cpu_2xlarge                    = var.cpu_2xlarge,
    cpu_4xlarge                    = var.cpu_4xlarge,
    cpu_6xlarge                    = var.cpu_6xlarge,
    cpu_8xlarge                    = var.cpu_8xlarge,
    cpu_20xlarge                   = var.cpu_20xlarge,
    debug                          = var.debug,
    sfn_definition_prefix          = var.sfn_definition_prefix,
    sfn_service_versions           = jsonencode(var.sfn_service_versions),
    sfn_backoff_limit              = var.sfn_backoff_limit
  }

  ## MM Step Function and SNS Message: 
  # mm_ingest_lrs_all_definition - MMLrsIngestAll
  # mm_ingest_initial_all_definition - MMInitialLoad
  # mm_ingest_delta_vicmap_definition - MMIVicMapDeltaLoad
  # mm_ingest_delta_osm_definition - MMIOsmDeltaLoad
  
  sfn_definition_vars_mm_load = "${var.sfn_definition_file_name == "mm_ingest_initial_all_definition.tftpl" || var.sfn_definition_file_name == "mm_ingest_delta_vicmap_definition.tftpl" || var.sfn_definition_file_name == "mm_ingest_delta_osm_definition.tftpl" || var.sfn_definition_file_name == "mm_ingest_bulk_edits_definition.tftpl"
    ? merge(local.sfn_definition_vars_common, {"sns_arn" = "${data.aws_sns_topic.triggering_lrs_sfn_lambda_mm_export_completion.arn}"}) : null}"
  sfn_definition_vars_mm_ingest_lrs_all     = "${var.sfn_definition_file_name == "mm_ingest_lrs_all_definition.tftpl" ? merge(local.sfn_definition_vars_common, {"sns_arn" = "${data.aws_sns_topic.triggering_lrs_sfn_lambda_lrs_mm_load_completion.arn}"}) : null}"
  sfn_definition_vars_others                = "${var.sfn_definition_file_name != "mm_ingest_initial_all_definition.tftpl" && var.sfn_definition_file_name != "mm_ingest_lrs_all_definition.tftpl" && var.sfn_definition_file_name != "mm_ingest_delta_vicmap_definition.tftpl" && var.sfn_definition_file_name != "mm_ingest_delta_osm_definition.tftpl" && var.sfn_definition_file_name != "mm_ingest_bulk_edits_definition.tftpl" 
    ? local.sfn_definition_vars_common : null}"

  service_integrations_shared_lambda = {
    lambda = {
      lambda = [module.lambda_function.lambda_function_arn]
    }
  }
  service_integrations_sns_mm_load = {
    sns = {
      sns = [data.aws_sns_topic.triggering_lrs_sfn_lambda_mm_export_completion.arn]
    }
  }
  service_integrations_sns_mm_ingest_lrs_all = {
    sns = {
      sns = [data.aws_sns_topic.triggering_lrs_sfn_lambda_lrs_mm_load_completion.arn]
    }
  }
  service_integrations_mm_load = "${var.sfn_definition_file_name == "mm_ingest_initial_all_definition.tftpl" || var.sfn_definition_file_name == "mm_ingest_delta_vicmap_definition.tftpl" || var.sfn_definition_file_name == "mm_ingest_delta_osm_definition.tftpl" || var.sfn_definition_file_name == "mm_ingest_bulk_edits_definition.tftpl" 
    ? merge(local.service_integrations_shared_lambda, local.service_integrations_sns_mm_load) : null}"
  service_integrations_mm_ingest_lrs_all     = "${var.sfn_definition_file_name == "mm_ingest_lrs_all_definition.tftpl" ? merge(local.service_integrations_shared_lambda, local.service_integrations_sns_mm_ingest_lrs_all) : null}"
  service_integrations_others                = "${var.sfn_definition_file_name != "mm_ingest_initial_all_definition.tftpl" && var.sfn_definition_file_name != "mm_ingest_lrs_all_definition.tftpl" && var.sfn_definition_file_name != "mm_ingest_delta_vicmap_definition.tftpl" && var.sfn_definition_file_name != "mm_ingest_delta_osm_definition.tftpl" && var.sfn_definition_file_name != "mm_ingest_bulk_edits_definition.tftpl"
    ? local.service_integrations_shared_lambda : null}"
}

# Step Function setup
module "step_function" {
  source     = "terraform-aws-modules/step-functions/aws"
  version    = "4.0.0"
  depends_on = [
    module.lambda_function
  ]

  name = local.sfn_name

  definition = templatefile(local.sfn_definition_path, coalesce(local.sfn_definition_vars_others, local.sfn_definition_vars_mm_load, local.sfn_definition_vars_mm_ingest_lrs_all))

  role_arn = var.sfn_role_arn

  service_integrations = coalesce(local.service_integrations_others, local.service_integrations_mm_load, local.service_integrations_mm_ingest_lrs_all)

  type = "STANDARD"

}


module "eventbridge" {
  source     = "terraform-aws-modules/eventbridge/aws"
  version    = "3.0.0"
  depends_on = [module.step_function]
  count      = var.create_eb ? 1 : 0

  role_name = "${local.sfn_name}-eventbridge"

  # create_bus = false
  # rules = {
  #   "${local.sfn_name}-crons" = {
  #     description         = var.eb_rule_schedule_expression_description
  #     schedule_expression = var.eb_rule_schedule_expression
  #     timezone            = "Australia/Sydney"
  #     start_date          = var.start_date
  #   }
  # }

  # targets = {
  #   "${local.sfn_name}-crons" = [
  #     {
  #       name            = local.sfn_name
  #       arn             = module.step_function.state_machine_arn
  #       attach_role_arn = true
  #     }
  #   ]
  # }

  bus_name = local.sfn_name
  schedules = {
    step-function-cron = {
      description         = var.eb_rule_schedule_expression_description
      schedule_expression = var.eb_rule_schedule_expression
      timezone            = "Australia/Sydney"
      arn                 = module.step_function.state_machine_arn
      # start_date          = var.start_date
      # input               = jsonencode({ "job" : "cron-by-rate" })
    }
  }

  sfn_target_arns   = [module.step_function.state_machine_arn]
  attach_sfn_policy = true
}


# Lambda function setup
module "lambda_function" {
  source     = "terraform-aws-modules/lambda/aws"
  version    = "6.0.0"
  depends_on = [data.aws_iam_role.lambda_orchestrate_eks]

  function_name = local.lambda_name
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  lambda_role   = data.aws_iam_role.lambda_orchestrate_eks.arn
  create_role   = false
  hash_extra    = "hash-extra-${local.lambda_name}"
  publish       = true
  timeout       = 10

  source_path = {
    path = "${path.module}/lambda"
  }

  vpc_subnet_ids         = var.eks_vpc_subnet_ids
  vpc_security_group_ids = var.eks_cluster_vpc_security_group_ids
  attach_network_policy  = true

  environment_variables = {
    ENV_PREFIX = var.env_prefix
  }

}

# Pre-defined IAM Role, can be found in https://dev.azure.com/dd-managed-services/Optimal-Reality/_git/env-or-client-dot-terraform, 02_resources folder {env}/main.tf
data "aws_iam_role" "lambda_orchestrate_eks" {
  name = "lambda-orchestrate-eks"
}

# Pre-defined AWS SNS in the "tf-module-fargate-tasks" repo
# Please make sure AWS SNS Topics has been deployed in this environment. 
data "aws_sns_topic" "triggering_lrs_sfn_lambda_mm_export_completion" {
  name = "${var.env_prefix}_mm_export_completion"
}

data "aws_sns_topic" "triggering_lrs_sfn_lambda_lrs_mm_load_completion" {
  name = "${var.env_prefix}_lrs_mm_load_completion"
}

# resource "aws_iam_role" "lambda_role" {
#   name = "${local.lambda_name}_role"
#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "lambda.amazonaws.com"
#       },
#       "Effect": "Allow"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_policy" "lambda_eks_policy" {
#   name   = "${local.lambda_name}_eks_policy"
#   policy = <<EOF
# {
#     "Statement": [
#         {
#             "Action": [
#                 "sts:GetCallerIdentity",
#                 "eks:DescribeCluster",
#                 "eks:AccessKubernetesApi"
#             ],
#             "Effect": "Allow",
#             "Resource": "arn:aws:eks:ap-southeast-2:729234215193:cluster/dev"
#         }
#     ],
#     "Version": "2012-10-17"
# }
# EOF
# }

# resource "aws_iam_role_policy_attachment" "lambda_AWSLambdaVPCAccessExecutionRole_attachment" {
#   role       = aws_iam_role.lambda_role.id
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
# }

# resource "aws_iam_role_policy_attachment" "lambda_eks_policy_attachment" {
#   role       = aws_iam_role.lambda_role.id
#   policy_arn = aws_iam_policy.lambda_eks_policy.arn
# }
