variable "region"{
    default = "TEMPLATE_REGION_NAME" 
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)

  default = [
    "TEMPLATE_ACCOUNT_ID",
  ]
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      username = "TEMPLATE_ADMIN_USERNAME"
      rolearn  = "TEMPLATE_ADMIN_ROLE"
      groups = ["system:masters"]
    },
  ]
}
