mock_provider "aws" {
  mock_resource "aws_organizations_organization" {
    defaults = {
      roots = [{ id = "r-test", arn = "arn:aws:organizations::000000000000:root/o-example/r-test", name = "Root", policy_types = [] }]
    }
  }
}

variables {
  account_emails = {
    security_audit   = "audit@example.com"
    workload_staging = "staging@example.com"
    workload_prod    = "prod@example.com"
    sandbox          = "sandbox@example.com"
  }
}

run "topology" {
  command = plan

  assert {
    condition = (
      aws_organizations_organization.this.feature_set == "ALL" &&
      aws_organizations_organization.this.aws_service_access_principals == toset(["sso.amazonaws.com"]) &&
      length(aws_organizations_organizational_unit.this) == 3 &&
      length(aws_organizations_account.this) == 4
    )
    error_message = "Expected ALL features, Identity Center trusted access, three OUs and four member accounts."
  }
}

run "reject_duplicate_emails" {
  command = plan
  variables {
    account_emails = {
      security_audit   = "audit@example.com"
      workload_staging = "staging@example.com"
      workload_prod    = "prod@example.com"
      sandbox          = "AUDIT@example.com"
    }
  }
  expect_failures = [var.account_emails]
}

run "reject_missing_account" {
  command = plan
  variables {
    account_emails = { sandbox = "sandbox@example.com" }
  }
  expect_failures = [var.account_emails]
}
