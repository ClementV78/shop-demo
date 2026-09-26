output "organization_id" {
  description = "Organization ID for subsequent governance modules."
  value       = aws_organizations_organization.this.id
}

output "root_id" {
  description = "Organization root ID; restrictive SCPs must not be attached here."
  value       = aws_organizations_organization.this.roots[0].id
}

output "ou_ids" {
  description = "OU IDs indexed by stable keys: security, workloads, sandbox."
  value       = { for key, ou in aws_organizations_organizational_unit.this : key => ou.id }
}

output "account_ids" {
  description = "Member account IDs indexed by stable account keys."
  value       = { for key, account in aws_organizations_account.this : key => account.id }
  sensitive   = true
}
