variable "account_ids" {
  description = "Member account IDs indexed by the organization module stable keys."
  type        = map(string)
  nullable    = false

  validation {
    condition = toset(keys(var.account_ids)) == toset([
      "security_audit", "workload_staging", "workload_prod", "sandbox"
    ])
    error_message = "Provide exactly security_audit, workload_staging, workload_prod and sandbox."
  }

  validation {
    condition     = alltrue([for account_id in values(var.account_ids) : can(regex("^[0-9]{12}$", account_id))])
    error_message = "Every account ID must contain exactly twelve digits."
  }
}
