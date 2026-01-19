resource "aws_ssm_parameter" "or_demo_rds_password" {
    name = "TEMPLATE_SSM_RDS_PASSWORD_KEY"
    type        = "SecureString"
    value       = "TEMPLATE_SSM_RDS_PASSWORD_VALUE"
}

resource "aws_ssm_parameter" "or_demo_rds_username" {
    name = "TEMPLATE_SSM_RDS_USERNAME_KEY"
    type        = "SecureString"
    value       = "TEMPLATE_SSM_RDS_USERNAME_VALUE"
}


resource "aws_ssm_parameter" "or_demo_master_password" {
    name = "TEMPLATE_SSM_RDS_MASTER_PASSWORD_KEY"
    type        = "SecureString"
    value       = "TEMPLATE_SSM_RDS_MASTER_PASSWORD_VALUE"
}
