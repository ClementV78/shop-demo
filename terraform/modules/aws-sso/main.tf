data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = one(data.aws_ssoadmin_instances.this.arns)
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)

  groups = {
    admin = {
      display_name = "ShopDemo-Admins"
      description  = "Emergency administrators; keep empty during normal operation."
    }
    developer = {
      display_name = "ShopDemo-Developers"
      description  = "Developers operating sandbox and staging accounts."
    }
    reader = {
      display_name = "ShopDemo-Readers"
      description  = "Read-only access across ShopDemo member accounts."
    }
  }

  permission_sets = {
    admin = {
      name               = "AdminAccess"
      description        = "Emergency administration of ShopDemo member accounts."
      session_duration   = "PT1H"
      managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    }
    developer = {
      name               = "DevAccess"
      description        = "Power-user access to sandbox and staging without broad IAM administration."
      session_duration   = "PT4H"
      managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
    }
    reader = {
      name               = "ReadOnly"
      description        = "Read-only access to every ShopDemo member account."
      session_duration   = "PT8H"
      managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
    }
  }

  assignment_matrix = {
    admin     = ["security_audit", "workload_staging", "workload_prod", "sandbox"]
    developer = ["workload_staging", "sandbox"]
    reader    = ["security_audit", "workload_staging", "workload_prod", "sandbox"]
  }

  assignments = merge([
    for permission_key, account_keys in local.assignment_matrix : {
      for account_key in account_keys : "${permission_key}:${account_key}" => {
        permission_key = permission_key
        account_id     = var.account_ids[account_key]
      }
    }
  ]...)
}

resource "aws_identitystore_group" "this" {
  for_each = local.groups

  identity_store_id = local.identity_store_id
  display_name      = each.value.display_name
  description       = each.value.description
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.permission_sets

  instance_arn     = local.instance_arn
  name             = each.value.name
  description      = each.value.description
  session_duration = each.value.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.permission_sets

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  managed_policy_arn = each.value.managed_policy_arn
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.assignments

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_key].arn
  principal_id       = aws_identitystore_group.this[each.value.permission_key].group_id
  principal_type     = "GROUP"
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"

  depends_on = [aws_ssoadmin_managed_policy_attachment.this]
}
