# Bucket qui hebergera les states Terraform du projet.
#
# Il est cree par un state local, puis heberge ce meme state apres migration.
# C'est la seule ressource du depot dans ce cas, et la raison pour laquelle
# le bloc backend de versions.tf reste absent jusqu'a la fin de S2-T2.

resource "aws_s3_bucket" "tfstate" {
  # Le nom d'un bucket est globalement unique et immuable. L'identifiant de
  # compte le rend unique sans reveler d'information utile a un tiers.
  bucket = "${local.name_prefix}-tfstate-${var.aws_account_id}"

  lifecycle {
    # Un renommage du bucket produirait un plan qui detruit le bucket
    # contenant le state en cours d'utilisation. Terraform doit refuser le
    # plan plutot que l'executer.
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # Le versioning est le filet de securite du state : il permet de revenir a
  # une version anterieure apres une corruption ou une suppression accidentelle.
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      # SSE-S3 plutot que SSE-KMS : une cle KMS geree couterait environ 1 USD
      # par mois plus les appels, pour un gain de controle sans usage reel ici.
      # Le compromis est assume et documente dans le fichier de sprint.
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # Un state Terraform expose publiquement revelerait toute l'infrastructure,
  # et parfois des valeurs sensibles en clair. Les quatre verrous sont poses.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    # Desactive completement les ACL : seule la policy de bucket fait autorite.
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # Le versioning conserve chaque revision du state. Sans bornage, le bucket
  # grossit indefiniment. Trente jours suffisent : une corruption de state se
  # detecte au plan suivant, pas des mois plus tard.
  rule {
    id     = "expirer-anciennes-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Un upload interrompu laisse des fragments factures et invisibles.
  rule {
    id     = "nettoyer-uploads-incomplets"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}
