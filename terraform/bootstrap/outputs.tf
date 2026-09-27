output "aws_region" {
  description = "Region AWS effectivement utilisee par ce state."
  value       = var.aws_region
}

output "name_prefix" {
  description = "Prefixe de nommage applique aux ressources de ce state."
  value       = local.name_prefix
}

output "common_tags" {
  description = "Tags obligatoires appliques automatiquement via default_tags."
  value       = local.common_tags
}

output "tfstate_bucket" {
  description = "Nom du bucket qui hebergera les states Terraform, a reporter dans le bloc backend."
  value       = aws_s3_bucket.tfstate.bucket
}

output "backend_config" {
  description = "Bloc backend a coller dans versions.tf une fois le bucket cree, pour l'etape de migration."
  value       = <<-EOT
    backend "s3" {
      bucket       = "${aws_s3_bucket.tfstate.bucket}"
      key          = "bootstrap/terraform.tfstate"
      region       = "${var.aws_region}"
      encrypt      = true
      use_lockfile = true
    }
  EOT
}

output "audit_log_bucket" {
  description = "Central S3 bucket for organization CloudTrail and member AWS Config delivery."
  value       = module.baseline.audit_log_bucket
}

output "organization_trail_arn" {
  description = "ARN of the multi-region organization CloudTrail."
  value       = module.baseline.organization_trail_arn
}
