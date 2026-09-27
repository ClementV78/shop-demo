output "audit_log_bucket" {
  description = "Name of the central audit bucket in the security-audit account."
  value       = aws_s3_bucket.audit.id
}

output "organization_trail_arn" {
  description = "ARN of the multi-region organization trail."
  value       = aws_cloudtrail.organization.arn
}

output "full_posture_enabled" {
  description = "Whether GuardDuty and the CIS Level 1 conformance pack are enabled in member accounts."
  value       = var.enable_full_posture
}
