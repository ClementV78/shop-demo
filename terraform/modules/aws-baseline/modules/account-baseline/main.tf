resource "aws_iam_role" "config" {
  name = "shopdemo-aws-config"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  name     = "shopdemo-${var.account_key}"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "this" {
  name           = "shopdemo-${var.account_key}"
  s3_bucket_name = var.audit_bucket_name
  s3_key_prefix  = "config"

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

resource "aws_config_config_rule" "required_tags" {
  name        = "shopdemo-required-tags"
  description = "Checks the five mandatory ShopDemo tags on supported AWS resources."
  input_parameters = jsonencode({
    tag1Key   = "Project"
    tag1Value = var.required_tag_values.Project
    tag2Key   = "Environment"
    tag2Value = var.required_tag_values.Environment
    tag3Key   = "Owner"
    tag3Value = var.required_tag_values.Owner
    tag4Key   = "ManagedBy"
    tag4Value = var.required_tag_values.ManagedBy
    tag5Key   = "Sprint"
    tag5Value = var.required_tag_values.Sprint
  })

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name        = "shopdemo-cloudtrail-enabled"
  description = "Checks that CloudTrail is enabled in the account."

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}

resource "aws_guardduty_detector" "this" {
  count = var.enable_full_posture ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_detector_feature" "s3_data_events" {
  count = var.enable_full_posture ? 1 : 0

  detector_id = aws_guardduty_detector.this[0].id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_config_conformance_pack" "cis_level_1" {
  count = var.enable_full_posture ? 1 : 0

  name          = "shopdemo-cis-aws-v1-4-level-1"
  template_body = var.cis_level_1_template

  depends_on = [aws_config_configuration_recorder_status.this]
}
