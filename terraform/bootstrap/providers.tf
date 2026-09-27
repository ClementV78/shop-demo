provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Garde-fou principal de ce state : Terraform refuse de s'executer si les
  # credentials resolus ne pointent pas sur le compte attendu. Sans cela, un
  # AWS_PROFILE oublie enverrait un apply dans un compte voisin, et la
  # creation d'une Organization en S2-T3 est difficilement reversible.
  allowed_account_ids = [var.aws_account_id]

  # default_tags applique les tags communs a toutes les ressources supportees,
  # sans les repeter. La regle AWS Config required-tags livree en S2-T6
  # s'appuie sur ces memes cles.
  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias               = "sandbox"
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [module.organization.account_ids["sandbox"]]

  assume_role {
    role_arn = "arn:aws:iam::${module.organization.account_ids["sandbox"]}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(local.common_tags, { Environment = "sandbox" })
  }
}

provider "aws" {
  alias               = "security_audit"
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [module.organization.account_ids["security_audit"]]

  assume_role {
    role_arn = "arn:aws:iam::${module.organization.account_ids["security_audit"]}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(local.common_tags, { Environment = "security-audit" })
  }
}

provider "aws" {
  alias               = "workload_staging"
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [module.organization.account_ids["workload_staging"]]

  assume_role {
    role_arn = "arn:aws:iam::${module.organization.account_ids["workload_staging"]}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(local.common_tags, { Environment = "staging" })
  }
}

provider "aws" {
  alias               = "workload_prod"
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [module.organization.account_ids["workload_prod"]]

  assume_role {
    role_arn = "arn:aws:iam::${module.organization.account_ids["workload_prod"]}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(local.common_tags, { Environment = "prod" })
  }
}
