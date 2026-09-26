resource "aws_organizations_policy" "deny_regions_outside_eu" {
  name        = "deny-regions-outside-eu"
  description = "Deny regional API calls outside eu-* with explicit global-service exceptions."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(jsondecode(file("${path.module}/policies/deny-regions-outside-eu.json")))
}

resource "aws_organizations_policy" "deny_iam_longterm_keys" {
  name        = "deny-iam-longterm-keys"
  description = "Deny creation of new IAM access keys; existing keys and STS sessions are unchanged."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(jsondecode(file("${path.module}/policies/deny-iam-longterm-keys.json")))
}

resource "aws_organizations_policy" "deny_root_usage" {
  name        = "deny-root-usage"
  description = "Deny member-account root actions subject to SCPs."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(jsondecode(file("${path.module}/policies/deny-root-usage.json")))
}

resource "aws_organizations_policy" "enforce_cloudtrail" {
  name        = "enforce-cloudtrail"
  description = "Prevent stopping or deleting trails; does not provision or fully protect logging."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(jsondecode(file("${path.module}/policies/enforce-cloudtrail.json")))
}

resource "aws_organizations_policy" "require_mfa_for_console" {
  name        = "require-mfa-for-console"
  description = "Require MFA context for direct IAM user actions; role sessions are excluded."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(jsondecode(file("${path.module}/policies/require-mfa-for-console.json")))
}

resource "aws_organizations_policy" "deny_public_s3" {
  name        = "deny-public-s3"
  description = "Freeze account S3 Block Public Access after all four safeguards are enabled."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(jsondecode(file("${path.module}/policies/deny-public-s3.json")))
}
