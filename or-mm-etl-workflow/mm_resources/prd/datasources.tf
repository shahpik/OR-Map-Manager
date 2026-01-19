data "terraform_remote_state" "management" {
  backend = "s3"

  config = {
    bucket = var.management_s3_bucket_name
    key    = "setup/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "environment_setup" {
  backend = "s3"

  config = {
    bucket = var.environment_s3_bucket_name
    key    = "setup/terraform.tfstate"
    region = var.aws_region
  }
}