mock_provider "aws" {}

run "iam_keys_scope" {
  command = plan

  assert {
    condition = (
      aws_organizations_policy.deny_iam_longterm_keys.type == "SERVICE_CONTROL_POLICY" &&
      jsondecode(aws_organizations_policy.deny_iam_longterm_keys.content).Statement == [{
        Sid      = "DenyNewIAMAccessKeys"
        Effect   = "Deny"
        Action   = "iam:CreateAccessKey"
        Resource = "*"
      }]
    )
    error_message = "Deny only new IAM access keys, leaving STS and key removal outside this guardrail."
  }
}
