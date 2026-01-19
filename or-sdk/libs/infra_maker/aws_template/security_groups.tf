
resource "aws_security_group" "or_demo_rds_security_group" {
    egress      = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = "Rule to allow all communication to the Internet"
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
    ingress     = [
      
        {
            cidr_blocks      = [
                "10.0.1.0/24",
            ]
            description      = "Rule to allow all communication from 10.0.1.0/24"
            from_port        = 5432
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 5432
        },
        {
            cidr_blocks      = [
                "10.0.2.0/24",
            ]
            description      = "Rule to allow all communication from 10.0.2.0/24"
            from_port        = 5432
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 5432
        },
        {
            cidr_blocks      = [
                "10.0.3.0/24",
            ]
             description      = "Rule to allow all communication from 10.0.3.0/24"
            from_port        = 5432
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 5432
        },

        {
            cidr_blocks      = []
            description      = "Rule to allow all communication from bastion host"
            from_port        = 5432
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = [aws_security_group.bastion_test.id]
            self             = false
            to_port          = 5432
        },
    ]
    name = "TEMPLATE_RDS_SECURITY_GROUP"
    vpc_id = module.vpc.vpc_id
  
}


resource "aws_security_group" "bastion_test" {
  name        = "TEMPLATE_BASTION_SECURITY_GROUP"
  description = "TEMPLATE_BASTION_SECURITY_GROUP"
  vpc_id      = module.vpc.vpc_id
  egress      = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = "Rule to allow all communication to the Internet"
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
}