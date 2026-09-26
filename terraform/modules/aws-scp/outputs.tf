output "deny_regions_outside_eu_policy_id" {
  description = "Policy ID for the subsequent, separately reviewed sandbox attachment."
  value       = aws_organizations_policy.deny_regions_outside_eu.id
}

output "deny_iam_longterm_keys_policy_id" {
  description = "Policy ID for the sandbox guardrail against new IAM access keys."
  value       = aws_organizations_policy.deny_iam_longterm_keys.id
}

output "deny_root_usage_policy_id" {
  description = "Policy ID for the deny-root-usage sandbox guardrail."
  value       = aws_organizations_policy.deny_root_usage.id
}

output "enforce_cloudtrail_policy_id" {
  description = "Policy ID for the enforce-cloudtrail sandbox guardrail."
  value       = aws_organizations_policy.enforce_cloudtrail.id
}

output "require_mfa_for_console_policy_id" {
  description = "Policy ID for the require-mfa-for-console sandbox guardrail."
  value       = aws_organizations_policy.require_mfa_for_console.id
}

output "deny_public_s3_policy_id" {
  description = "Policy ID for the deny-public-s3 sandbox guardrail."
  value       = aws_organizations_policy.deny_public_s3.id
}
