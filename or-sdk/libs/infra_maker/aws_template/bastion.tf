module "ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"


  name                        = "TEMPLATE_BASTION_INSTANCE_NAME"
  ami                         = "TEMPLATE_REGION_AMI"
  instance_type               = "TEMPLATE_BASTION_INSTANCE_TYPE"
  subnet_id                   =  module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name = "TEMPLATE_BASTION_KEY_NAME"
  vpc_security_group_ids = [aws_security_group.bastion_test.id]
}