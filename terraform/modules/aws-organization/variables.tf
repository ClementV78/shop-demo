variable "account_emails" {
  description = "Private email addresses for the four member accounts; supply through untracked tfvars."
  type        = map(string)
  sensitive   = true
  nullable    = false

  validation {
    condition = toset(keys(var.account_emails)) == toset([
      "security_audit", "workload_staging", "workload_prod", "sandbox"
    ])
    error_message = "Provide exactly security_audit, workload_staging, workload_prod and sandbox."
  }

  validation {
    condition = alltrue([for email in values(var.account_emails) :
      can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email)) && length(email) <= 64
    ])
    error_message = "Provide valid email addresses of at most 64 characters."
  }

  validation {
    condition     = length(distinct([for email in values(var.account_emails) : lower(email)])) == 4
    error_message = "Each account must have a distinct email address."
  }
}
