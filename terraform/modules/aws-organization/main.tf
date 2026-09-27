locals {
  organizational_units = {
    security  = "Security"
    workloads = "Workloads"
    sandbox   = "Sandbox"
  }
  accounts = {
    security_audit   = { name = "security-audit", ou = "security" }
    workload_staging = { name = "workload-staging", ou = "workloads" }
    workload_prod    = { name = "workload-prod", ou = "workloads" }
    sandbox          = { name = "sandbox", ou = "sandbox" }
  }
}

resource "aws_organizations_organization" "this" {
  feature_set          = "ALL"
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "sso.amazonaws.com",
  ]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "this" {
  for_each  = local.organizational_units
  name      = each.value
  parent_id = aws_organizations_organization.this.roots[0].id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_account" "this" {
  for_each          = local.accounts
  name              = each.value.name
  email             = var.account_emails[each.key]
  parent_id         = aws_organizations_organizational_unit.this[each.value.ou].id
  close_on_deletion = false

  lifecycle {
    prevent_destroy = true
  }
}
