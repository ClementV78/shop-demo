variable "account_key" {
  description = "Stable account name used in resource names and S3 prefixes."
  type        = string
}

variable "audit_bucket_name" {
  description = "Central S3 bucket that receives AWS Config snapshots and history."
  type        = string
}

variable "cis_level_1_template" {
  description = "AWS sample conformance pack template for CIS AWS Foundations Benchmark v1.4 Level 1."
  type        = string
}

variable "enable_full_posture" {
  description = "Create GuardDuty and the CIS Level 1 conformance pack in this account."
  type        = bool
}

variable "required_tag_values" {
  description = "Required tag keys and their optional values for the baseline AWS Config rule."
  type = object({
    Project     = string
    Environment = string
    Owner       = string
    ManagedBy   = string
    Sprint      = string
  })
}
