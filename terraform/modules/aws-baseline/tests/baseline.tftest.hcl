mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-1"
      name   = "eu-west-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "aws" {
  alias = "security_audit"
}

mock_provider "aws" {
  alias = "workload_staging"
}

mock_provider "aws" {
  alias = "workload_prod"
}

mock_provider "aws" {
  alias = "sandbox"
}

variables {
  project                = "shopdemo"
  owner                  = "shopdemo"
  organization_id        = "o-abcdefghij"
  management_account_id  = "000000000000"
  alert_email            = "alerts@example.com"
  monthly_budget_amount  = 25
  billed_budget_amount   = 1
  cost_anomaly_threshold = 5
  account_ids = {
    security_audit   = "000000000001"
    workload_staging = "000000000002"
    workload_prod    = "000000000003"
    sandbox          = "000000000004"
  }
}

run "permanent_baseline" {
  command = plan

  assert {
    condition = (
      length(aws_budgets_budget.cost_view) == 2 &&
      aws_budgets_budget.cost_view["actual"].limit_amount == "25" &&
      aws_budgets_budget.cost_view["billed"].limit_amount == "1" &&
      aws_cloudtrail.organization.is_multi_region_trail &&
      aws_cloudtrail.organization.is_organization_trail &&
      aws_cloudtrail.organization.enable_log_file_validation
    )
    error_message = "The permanent baseline must include two budgets and a validated multi-region organization trail."
  }

  assert {
    condition = (
      !module.security_audit.full_posture_enabled &&
      !module.workload_staging.full_posture_enabled &&
      !module.workload_prod.full_posture_enabled &&
      !module.sandbox.full_posture_enabled &&
      module.security_audit.full_posture_resource_count == 0 &&
      module.workload_staging.full_posture_resource_count == 0 &&
      module.workload_prod.full_posture_resource_count == 0 &&
      module.sandbox.full_posture_resource_count == 0
    )
    error_message = "GuardDuty must remain absent while the full posture is disabled."
  }
}

run "full_posture" {
  command = plan

  variables {
    enable_full_posture = true
  }

  assert {
    condition = (
      module.security_audit.full_posture_enabled &&
      module.workload_staging.full_posture_enabled &&
      module.workload_prod.full_posture_enabled &&
      module.sandbox.full_posture_enabled &&
      module.security_audit.full_posture_resource_count == 3 &&
      module.workload_staging.full_posture_resource_count == 3 &&
      module.workload_prod.full_posture_resource_count == 3 &&
      module.sandbox.full_posture_resource_count == 3
    )
    error_message = "The full posture must create one GuardDuty detector in each member account."
  }
}
