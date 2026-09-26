mock_provider "aws" {}

run "regional_policy_contract" {
  command = plan

  assert {
    condition = (
      aws_organizations_policy.deny_regions_outside_eu.type == "SERVICE_CONTROL_POLICY" &&
      length(aws_organizations_policy.deny_regions_outside_eu.content) <= 5120 &&
      jsondecode(aws_organizations_policy.deny_regions_outside_eu.content).Statement[0].Effect == "Deny"
    )
    error_message = "The regional guardrail must be a Deny SCP within the policy size limit."
  }
}
