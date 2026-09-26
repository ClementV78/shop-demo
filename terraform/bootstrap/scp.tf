module "scp" {
  source = "../modules/aws-scp"

  depends_on = [module.organization]
}

resource "aws_organizations_policy_attachment" "regional_sandbox" {
  policy_id = module.scp.deny_regions_outside_eu_policy_id
  target_id = module.organization.account_ids["sandbox"]
}

resource "aws_organizations_policy_attachment" "iam_keys_sandbox" {
  policy_id = module.scp.deny_iam_longterm_keys_policy_id
  target_id = module.organization.account_ids["sandbox"]
}

resource "aws_organizations_policy_attachment" "root_sandbox" {
  policy_id = module.scp.deny_root_usage_policy_id
  target_id = module.organization.account_ids["sandbox"]
}

resource "aws_organizations_policy_attachment" "cloudtrail_sandbox" {
  policy_id = module.scp.enforce_cloudtrail_policy_id
  target_id = module.organization.account_ids["sandbox"]
}

resource "aws_organizations_policy_attachment" "mfa_sandbox" {
  policy_id = module.scp.require_mfa_for_console_policy_id
  target_id = module.organization.account_ids["sandbox"]
}

resource "aws_organizations_policy_attachment" "public_s3_sandbox" {
  policy_id = module.scp.deny_public_s3_policy_id
  target_id = module.organization.account_ids["sandbox"]

  depends_on = [aws_s3_account_public_access_block.sandbox]
}
