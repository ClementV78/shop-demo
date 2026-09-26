output "group_ids" {
  description = "Identity Center group IDs indexed by admin, developer and reader."
  value       = { for key, group in aws_identitystore_group.this : key => group.group_id }
}

output "permission_set_arns" {
  description = "Permission set ARNs indexed by admin, developer and reader."
  value       = { for key, permission_set in aws_ssoadmin_permission_set.this : key => permission_set.arn }
}

output "instance_arn" {
  description = "Organization instance ARN discovered in the configured AWS Region."
  value       = local.instance_arn
}
