variable "project" {
  description = "Project name used to create globally unique and readable resource names."
  type        = string
}

variable "owner" {
  description = "Expected value of the mandatory Owner tag."
  type        = string
}

variable "organization_id" {
  description = "AWS Organizations identifier authorized to deliver organization trail logs."
  type        = string

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "Provide a valid AWS Organizations ID."
  }
}

variable "management_account_id" {
  description = "Management account ID used in globally unique names and confused-deputy conditions."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "Provide a twelve-digit management account ID."
  }
}

variable "account_ids" {
  description = "Member account IDs indexed by security_audit, workload_staging, workload_prod and sandbox."
  type        = map(string)

  validation {
    condition = toset(keys(var.account_ids)) == toset([
      "security_audit", "workload_staging", "workload_prod", "sandbox"
    ]) && alltrue([for id in values(var.account_ids) : can(regex("^[0-9]{12}$", id))])
    error_message = "Provide exactly four valid member account IDs."
  }
}

variable "alert_email" {
  description = "Email address used by AWS Budgets and Cost Anomaly Detection. Stored in Terraform state."
  type        = string
  sensitive   = true
}

variable "monthly_budget_amount" {
  description = "Monthly threshold in USD for the real usage view."
  type        = number
  default     = 25

  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "The monthly budget amount must be greater than zero."
  }
}

variable "billed_budget_amount" {
  description = "Low monthly threshold in USD for the post-credit billed cost view."
  type        = number
  default     = 1

  validation {
    condition     = var.billed_budget_amount > 0
    error_message = "The billed budget amount must be greater than zero."
  }
}

variable "cost_anomaly_threshold" {
  description = "Minimum absolute anomaly impact in USD that triggers an alert."
  type        = number
  default     = 5

  validation {
    condition     = var.cost_anomaly_threshold > 0
    error_message = "The anomaly threshold must be greater than zero."
  }
}

variable "enable_full_posture" {
  description = "Create temporary GuardDuty detectors and CIS Level 1 Config conformance packs in member accounts."
  type        = bool
  default     = false
}
