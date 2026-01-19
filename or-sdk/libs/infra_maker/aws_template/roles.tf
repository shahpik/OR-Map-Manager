resource "aws_iam_role" "test_role" {
    assume_role_policy    = jsonencode(
        {
            Statement = [
                {
                    Action    = "sts:AssumeRoleWithWebIdentity"
                    Effect    = "Allow"
                    Principal = {
                        Federated = "TEMPLATE_OIDC_PROVIDER_ARN"
                    }
                },
            ]
            Version   = "2012-10-17"
        }
    )
    force_detach_policies = false
    max_session_duration  = 3600
    path                  = "/"
    permissions_boundary  = "TEMPLATE_DELOITTE_PERMISSIONS_BOUNDARY_POLICY"
}