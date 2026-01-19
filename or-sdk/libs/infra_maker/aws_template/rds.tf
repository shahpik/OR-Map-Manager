module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "2.20.0"
  allocated_storage = 60
  backup_window = "00:00-01:00"
  engine = "postgres"
  engine_version = "12.3"
  final_snapshot_identifier = "TEMPLATE_RDS_IDENTIFIER"
  identifier = "TEMPLATE_RDS_IDENTIFIER"
  instance_class = "TEMPLATE_RDS_INSTANCE_CLASS"
  maintenance_window = "wed:02:00-wed:03:00"
  port = 5432
  username = aws_ssm_parameter.or_demo_rds_username.value
  password = aws_ssm_parameter.or_demo_rds_password.value
  availability_zone = "TEMPLATE_RDS_AVAILABILITY_ZONE"
  backup_retention_period = 14
  copy_tags_to_snapshot = true
  db_subnet_group_name =  aws_db_subnet_group.or_demo_rds_subnet_group.name
  deletion_protection = false
  iam_database_authentication_enabled = false
  create_db_parameter_group = false
  parameter_group_name = aws_db_parameter_group.or_demo_rds_pg.name
  option_group_name                     = "default:postgres-12"
  major_engine_version = "12"

  iops = 0
  kms_key_id                            = "TEMPLATE_KMS_KEY_ID"
  name = "TEMPLATE_RDS_NAME"
  option_group_description = "default:postgres-12"
  storage_encrypted = true
  storage_type = "gp2"
  vpc_security_group_ids = [aws_security_group.or_demo_rds_security_group.id]
}


resource "aws_db_parameter_group" "or_demo_rds_pg" {
    description = "Postgres 12 RDS Parameter Group"
    family      = "postgres12"
    name        = "TEMPLATE_RDS_PARAMETER_GROUP"
}


# provider "postgresql" {
#   alias    = "pg1"
#   scheme   = "awspostgres"
#   host     = module.rds.this_db_instance_endpoint
#   username = aws_ssm_parameter.or_demo_rds_username.value
#   port     = 5432
#   password = aws_ssm_parameter.or_demo_rds_password.value

#   superuser = false
# }


# resource "postgresql_database" "or_dot" {
#   provider = "postgresql.pg1"
#   name     = "or_dot"
# }


# resource "postgresql_database" "ordb" {
#   provider = "postgresql.pg1"
#   name     = "ordb"
# }


# resource "postgresql_role" "pgadmin" {
#   provider = "postgresql.pg1"
#   name     = "pgadmin"
#   login    = true
#   inherit = true
#   create_role = true
#   password = aws_ssm_parameter.or_demo_rds_password.value
# }

# resource "postgresql_role" "oradmin" {
#   provider = "postgresql.pg1"
#   name     = "oradmin"
#   login    = true
#   inherit = true
#   create_role = true
#   password = aws_ssm_parameter.or_demo_rds_password.value
# }
