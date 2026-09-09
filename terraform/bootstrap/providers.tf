provider "aws" {
  region = var.aws_region

  # default_tags applique les tags communs a toutes les ressources supportees
  # sans avoir a les repeter. La regle AWS Config required-tags livree en
  # S2-T6 s'appuie sur ces memes cles.
  default_tags {
    tags = local.common_tags
  }
}
