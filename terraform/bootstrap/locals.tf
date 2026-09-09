locals {
  # Prefixe de nommage unique pour toutes les ressources de ce state.
  # Les ressources a nom globalement unique, buckets S3 notamment, ajoutent
  # en plus l'identifiant de compte, ajoute en S2-T2.
  name_prefix = "${var.project}-${var.environment}"

  # Tags obligatoires du projet. Toute ressource creee sans ces tags sera
  # signalee non conforme par la regle AWS Config required-tags de S2-T6.
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Sprint      = "S2"
  }
}
