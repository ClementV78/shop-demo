locals {
  audit_bucket_name = "${var.project}-audit-logs-${var.management_account_id}"
  member_account_ids = [
    var.account_ids["security_audit"],
    var.account_ids["workload_staging"],
    var.account_ids["workload_prod"],
    var.account_ids["sandbox"],
  ]
  cis_level_1_template = file("${path.module}/templates/Operational-Best-Practices-for-CIS-AWS-v1.4-Level1.yaml")
}

data "aws_region" "current" {}

data "aws_partition" "current" {}

resource "aws_s3_bucket" "audit" {
  provider = aws.security_audit

  bucket = local.audit_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "audit" {
  provider = aws.security_audit

  bucket = aws_s3_bucket.audit.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  provider = aws.security_audit

  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  provider = aws.security_audit

  bucket = aws_s3_bucket.audit.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  provider = aws.security_audit

  bucket = aws_s3_bucket.audit.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  provider = aws.security_audit

  bucket = aws_s3_bucket.audit.id

  rule {
    id     = "expire-audit-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  depends_on = [aws_s3_bucket_versioning.audit]
}

data "aws_iam_policy_document" "audit_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.audit.arn,
      "${aws_s3_bucket.audit.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "CloudTrailBucketAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.audit.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${var.management_account_id}:trail/${var.project}-organization"]
    }
  }

  statement {
    sid    = "CloudTrailManagementAccountWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit.arn}/cloudtrail/AWSLogs/${var.management_account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${var.management_account_id}:trail/${var.project}-organization"]
    }
  }

  statement {
    sid    = "CloudTrailOrganizationWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit.arn}/cloudtrail/AWSLogs/${var.organization_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:${data.aws_region.current.region}:${var.management_account_id}:trail/${var.project}-organization"]
    }
  }

  statement {
    sid    = "ConfigBucketAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.audit.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = local.member_account_ids
    }
  }

  statement {
    sid    = "ConfigWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["s3:PutObject"]
    resources = [
      for account_id in local.member_account_ids :
      "${aws_s3_bucket.audit.arn}/config/AWSLogs/${account_id}/Config/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = local.member_account_ids
    }
  }
}

resource "aws_s3_bucket_policy" "audit" {
  provider = aws.security_audit

  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.audit_bucket.json
}

resource "aws_cloudtrail" "organization" {
  name                          = "${var.project}-organization"
  s3_bucket_name                = aws_s3_bucket.audit.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true
  enable_logging                = true

  event_selector {
    include_management_events = true
    read_write_type           = "All"
  }

  depends_on = [aws_s3_bucket_policy.audit]
}

module "security_audit" {
  source = "./modules/account-baseline"

  providers = { aws = aws.security_audit }

  account_key          = "security-audit"
  audit_bucket_name    = aws_s3_bucket.audit.id
  cis_level_1_template = local.cis_level_1_template
  enable_full_posture  = var.enable_full_posture
  required_tag_values = {
    Project     = var.project
    Environment = "security-audit"
    Owner       = var.owner
    ManagedBy   = "terraform"
    Sprint      = "S2"
  }
}

module "workload_staging" {
  source = "./modules/account-baseline"

  providers = { aws = aws.workload_staging }

  account_key          = "workload-staging"
  audit_bucket_name    = aws_s3_bucket.audit.id
  cis_level_1_template = local.cis_level_1_template
  enable_full_posture  = var.enable_full_posture
  required_tag_values = {
    Project     = var.project
    Environment = "staging"
    Owner       = var.owner
    ManagedBy   = "terraform"
    Sprint      = "S2"
  }
}

module "workload_prod" {
  source = "./modules/account-baseline"

  providers = { aws = aws.workload_prod }

  account_key          = "workload-prod"
  audit_bucket_name    = aws_s3_bucket.audit.id
  cis_level_1_template = local.cis_level_1_template
  enable_full_posture  = var.enable_full_posture
  required_tag_values = {
    Project     = var.project
    Environment = "prod"
    Owner       = var.owner
    ManagedBy   = "terraform"
    Sprint      = "S2"
  }
}

module "sandbox" {
  source = "./modules/account-baseline"

  providers = { aws = aws.sandbox }

  account_key          = "sandbox"
  audit_bucket_name    = aws_s3_bucket.audit.id
  cis_level_1_template = local.cis_level_1_template
  enable_full_posture  = var.enable_full_posture
  required_tag_values = {
    Project     = var.project
    Environment = "sandbox"
    Owner       = var.owner
    ManagedBy   = "terraform"
    Sprint      = "S2"
  }
}

resource "aws_budgets_budget" "cost_view" {
  for_each = {
    actual = {
      name             = "${var.project}-cout-reel"
      amount           = var.monthly_budget_amount
      include_credit   = false
      include_discount = false
    }
    billed = {
      name             = "${var.project}-cout-facture"
      amount           = var.billed_budget_amount
      include_credit   = true
      include_discount = true
    }
  }

  name         = each.value.name
  budget_type  = "COST"
  limit_amount = tostring(each.value.amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit             = each.value.include_credit
    include_discount           = each.value.include_discount
    include_other_subscription = true
    include_recurring          = true
    include_refund             = each.value.include_credit
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = false
    use_blended                = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
  }
}

resource "aws_ce_anomaly_monitor" "linked_accounts" {
  name              = "${var.project}-linked-accounts"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "LINKED_ACCOUNT"
}

resource "aws_ce_anomaly_subscription" "daily" {
  name             = "${var.project}-daily-cost-anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.linked_accounts.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.cost_anomaly_threshold)]
    }
  }
}
