output "state_machine_arns" {
  value = { for k, v in module.mm_etl_workflow : k => v.state_machine_arn }
}
