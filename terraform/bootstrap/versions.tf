terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Configuration partielle et volontaire. Le nom du bucket contient
  # l'identifiant du compte, qui n'est jamais versionne : il vit dans
  # backend.hcl, ignore par git, passe via -backend-config a l'init.
  #
  # use_lockfile utilise le verrou S3 natif, disponible depuis Terraform 1.10,
  # ce qui rend inutile la table DynamoDB historique.
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
