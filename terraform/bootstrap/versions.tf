terraform {
  required_version = "~> 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Le backend S3 est volontairement absent en S2-T1.
  # Il ne peut pas exister avant le bucket qui l'heberge, cree en S2-T2.
  # Jusque la, le state reste local et n'est jamais commite.
  # S2-T2 ajoutera ici un bloc backend "s3" avec use_lockfile = true,
  # le verrou natif disponible depuis Terraform 1.10, qui rend inutile
  # la table DynamoDB historique.
}
