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
