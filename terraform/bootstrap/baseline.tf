module "baseline" {
  source = "../modules/aws-baseline"

  providers = {
    aws                  = aws
    aws.security_audit   = aws.security_audit
    aws.workload_staging = aws.workload_staging
    aws.workload_prod    = aws.workload_prod
    aws.sandbox          = aws.sandbox
  }

  project                = var.project
  owner                  = var.owner
  organization_id        = module.organization.organization_id
  management_account_id  = var.aws_account_id
  account_ids            = nonsensitive(module.organization.account_ids)
  alert_email            = var.alert_email
  monthly_budget_amount  = var.monthly_budget_amount
  billed_budget_amount   = var.billed_budget_amount
  cost_anomaly_threshold = var.cost_anomaly_threshold
  enable_full_posture    = var.enable_full_posture

  depends_on = [module.organization]
}
