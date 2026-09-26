module "sso" {
  source = "../modules/aws-sso"

  account_ids = nonsensitive(module.organization.account_ids)

  depends_on = [module.organization]
}
