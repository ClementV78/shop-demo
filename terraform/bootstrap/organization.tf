module "organization" {
  source = "../modules/aws-organization"

  account_emails = var.account_emails
}
