mock_provider "aws" {
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns               = ["arn:aws:sso:::instance/ssoins-example"]
      identity_store_ids = ["d-example"]
    }
  }
}

variables {
  account_ids = {
    security_audit   = "000000000001"
    workload_staging = "000000000002"
    workload_prod    = "000000000003"
    sandbox          = "000000000004"
  }
}

run "access_matrix" {
  command = plan

  assert {
    condition = (
      length(aws_identitystore_group.this) == 3 &&
      length(aws_ssoadmin_permission_set.this) == 3 &&
      length(aws_ssoadmin_managed_policy_attachment.this) == 3 &&
      length(aws_ssoadmin_account_assignment.this) == 10
    )
    error_message = "Expected three groups, three permission sets and ten account assignments."
  }

  assert {
    condition = (
      aws_ssoadmin_permission_set.this["admin"].session_duration == "PT1H" &&
      aws_ssoadmin_permission_set.this["developer"].session_duration == "PT4H" &&
      aws_ssoadmin_permission_set.this["reader"].session_duration == "PT8H"
    )
    error_message = "Session durations must remain shortest for administrators."
  }

  assert {
    condition = (
      contains(keys(aws_ssoadmin_account_assignment.this), "developer:sandbox") &&
      contains(keys(aws_ssoadmin_account_assignment.this), "developer:workload_staging") &&
      !contains(keys(aws_ssoadmin_account_assignment.this), "developer:workload_prod") &&
      !contains(keys(aws_ssoadmin_account_assignment.this), "developer:security_audit")
    )
    error_message = "DevAccess must target only sandbox and workload-staging."
  }
}

run "reject_incomplete_accounts" {
  command = plan

  variables {
    account_ids = {
      sandbox = "000000000004"
    }
  }

  expect_failures = [var.account_ids]
}
