output "config_recorder_name" {
  description = "AWS Config recorder name."
  value       = aws_config_configuration_recorder.this.name
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID when the full posture is enabled."
  value       = try(aws_guardduty_detector.this[0].id, null)
}

output "full_posture_enabled" {
  description = "Whether this account plans the optional GuardDuty detector and CIS conformance pack."
  value       = var.enable_full_posture
}

output "full_posture_resource_count" {
  description = "Number of optional resources planned for this account."
  value = (
    length(aws_guardduty_detector.this) +
    length(aws_guardduty_detector_feature.s3_data_events) +
    length(aws_config_conformance_pack.cis_level_1)
  )
}
