module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.17"
  subnets         = module.vpc.private_subnets

  tags = {
    Environment = "test"

  }

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      instance_type = "TEMPLATE_EKS_CLUSTER_INSTANCE_TYPE"
      asg_max_size  = 2
      root_volume_type = "gp2"
      asg_desired_capacity = 1
    }
  ]

  # worker_additional_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  map_roles                            = var.map_roles
  map_accounts                         = var.map_accounts
}