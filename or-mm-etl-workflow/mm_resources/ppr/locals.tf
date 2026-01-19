locals {
  mm_etl_workflow = {
    mm_ingest_delta_osm = {
      create_eb                               = false
      eb_rule_schedule_expression             = "cron(0 0 1,15 * ? *)"
      eb_rule_schedule_expression_description = "Trigger at 12:00 AM UTC, on 1 and 15 of every month"
      sfn_name                                = "mm_ingest_delta_osm"
      sfn_definition_file_name                = "mm_ingest_delta_osm_definition.tftpl"
      sfn_definition_prefix                   = "mm-ingest-delta-osm"
      lambda_name                             = "mm_ingest_delta_osm"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_ingest_initial_all = {
      create_eb                               = false
      eb_rule_schedule_expression             = "na"
      eb_rule_schedule_expression_description = "Triggered Manully"
      sfn_name                                = "mm_ingest_initial_all"
      sfn_definition_file_name                = "mm_ingest_initial_all_definition.tftpl"
      sfn_definition_prefix                   = "mm-ingest-initial-all"
      lambda_name                             = "mm_ingest_initial_all"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_ingest_lrs_all = {
      create_eb                               = true
      eb_rule_schedule_expression             = "rate(1 day)"
      eb_rule_schedule_expression_description = "Trigger at 2:00 AM, on every day"
      sfn_name                                = "mm_ingest_lrs_all"
      sfn_definition_file_name                = "mm_ingest_lrs_all_definition.tftpl"
      sfn_definition_prefix                   = "mm-ingest-lrs-all"
      lambda_name                             = "mm_ingest_lrs_all"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_ingest_delta_vicmap = {
      create_eb                               = false
      eb_rule_schedule_expression             = "cron(0 0 9,23 * ? *)"
      eb_rule_schedule_expression_description = "Trigger at 12:00 AM UTC, on 9 and 23 of every month"
      sfn_name                                = "mm_ingest_delta_vicmap"
      sfn_definition_file_name                = "mm_ingest_delta_vicmap_definition.tftpl"
      sfn_definition_prefix                   = "mm-ingest-delta-vicmap"
      lambda_name                             = "mm_ingest_delta_vicmap"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_publish_osm = {
      create_eb                               = false
      eb_rule_schedule_expression             = "rate(120 minutes)"
      eb_rule_schedule_expression_description = "Run state machine every 2 hours"
      sfn_name                                = "mm_publish_osm"
      sfn_definition_file_name                = "mm_publish_osm_definition.tftpl"
      sfn_definition_prefix                   = "mm-publish-osm"
      lambda_name                             = "mm_publish_osm"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_publish_vicmap = {
      create_eb                               = false
      eb_rule_schedule_expression             = "rate(240 minutes)"
      eb_rule_schedule_expression_description = "Run state machine every 4 hours"
      sfn_name                                = "mm_publish_vicmap"
      sfn_definition_file_name                = "mm_publish_vicmap_definition.tftpl"
      sfn_definition_prefix                   = "mm-publish-vicmap"
      lambda_name                             = "mm_publish_vicmap"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_seed_custom_attribute_value = {
      create_eb                               = false
      eb_rule_schedule_expression             = "na"
      eb_rule_schedule_expression_description = "Triggered Manually"
      sfn_name                                = "mm_seed_custom_attribute_value"
      sfn_definition_file_name                = "mm_seed_custom_attribute_value_definition.tftpl"
      sfn_definition_prefix                   = "mm-seed-custom-attribute-value"
      lambda_name                             = "mm_seed_custom_attribute_value"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
      },
    mm_map_importer_generic = {
      create_eb                               = false
      eb_rule_schedule_expression             = "na"
      eb_rule_schedule_expression_description = "Triggered Manually"
      sfn_name                                = "mm_map_importer_generic"
      sfn_definition_file_name                = "mm_map_importer_generic_definition.tftpl"
      sfn_definition_prefix                   = "mm-map-importer-generic"
      lambda_name                             = "mm_map_importer_generic"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_map_editor_generic = {
      create_eb                               = false
      eb_rule_schedule_expression             = "na"
      eb_rule_schedule_expression_description = "Triggered Manually"
      sfn_name                                = "mm_map_editor_generic"
      sfn_definition_file_name                = "mm_map_editor_generic_definition.tftpl"
      sfn_definition_prefix                   = "mm-map-editor-generic"
      lambda_name                             = "mm_map_editor_generic"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_map_exporter_generic = {
      create_eb                               = false
      eb_rule_schedule_expression             = "na"
      eb_rule_schedule_expression_description = "Triggered Manually"
      sfn_name                                = "mm_map_exporter_generic"
      sfn_definition_file_name                = "mm_map_exporter_generic_definition.tftpl"
      sfn_definition_prefix                   = "mm-map-exporter-generic"
      lambda_name                             = "mm_map_exporter_generic"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
    mm_map_matcher_generic = {
      create_eb                               = false
      eb_rule_schedule_expression             = "na"
      eb_rule_schedule_expression_description = "Triggered Manually"
      sfn_name                                = "mm_map_matcher_generic"
      sfn_definition_file_name                = "mm_map_matcher_generic_definition.tftpl"
      sfn_definition_prefix                   = "mm-map-matcher-generic"
      lambda_name                             = "mm_map_matcher_generic"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    },
      mm_ingest_bulk_edits = {
      create_eb                               = false
      eb_rule_schedule_expression             = "cron(0 13 * * ? *)"
      eb_rule_schedule_expression_description = "Trigger at 12:00 AM, on 9 and 23 of every month"
      sfn_name                                = "mm_ingest_bulk_edits"
      sfn_definition_file_name                = "mm_ingest_bulk_edits_definition.tftpl"
      sfn_definition_prefix                   = "mm-ingest-bulk-edits"
      lambda_name                             = "mm_ingest_bulk_edits"
      lambda_handler                          = "lambda_function.lambda_handler"
      lambda_runtime                          = "python3.8"
      sfn_backoff_limit                       = 3
    }
  }
}

locals {
  sfn_service_versions = {
    MapImporter = {
      version = "1.0.0"
      image   = "558662781408.dkr.ecr.ap-southeast-2.amazonaws.com/or-dtp-map-importer"
    }
    MapIntersectionExporter = {
      version = "1.0.0"
      image   = "558662781408.dkr.ecr.ap-southeast-2.amazonaws.com/or-dtp-map-intersection-exporter"
    }
    MapExporter = {
      version = "1.0.0"
      image   = "558662781408.dkr.ecr.ap-southeast-2.amazonaws.com/or-dtp-map-exporter"
    }
    MapMatcher = {
      version = "1.0.0"
      image   = "558662781408.dkr.ecr.ap-southeast-2.amazonaws.com/or-dtp-map-matcher"
    }
    MapEditor = {
      version = "1.0.1"
      image   = "558662781408.dkr.ecr.ap-southeast-2.amazonaws.com/or-dtp-map-editor"
    }
  }
}

locals {
  # cpu
  cpu_small   = "200m"
  cpu_medium  = "400m"
  cpu_large   = "600m"
  cpu_xlarge  = "800m"
  cpu_2xlarge = "1000m"
  cpu_4xlarge = "2000m"
  cpu_6xlarge = "3000m"
  cpu_8xlarge = "4000m"
  cpu_20xlarge = "10000m"

  # memory
  memory_small    = "400Mi"
  memory_medium   = "700Mi"
  memory_large    = "1Gi"
  memory_xlarge   = "1.3Gi"
  memory_2xlarge  = "1.6Gi"
  memory_3xlarge  = "2Gi"
  memory_5xlarge  = "5Gi"
  memory_10xlarge = "10Gi"
  memory_20xlarge = "20Gi"
  memory_30xlarge = "30Gi"
  memory_50xlarge = "50Gi"

  # eks
  eks_vpc_subnet_ids                 = ["subnet-0181f452d362ebaae", "subnet-08e49bbef3bd27c42", "subnet-0c6a2e844bafb4f4b"]
  eks_cluster_vpc_security_group_ids = ["sg-08375a3300c6090ad"]
}
