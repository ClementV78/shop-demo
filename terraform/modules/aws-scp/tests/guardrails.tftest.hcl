mock_provider "aws" {}

run "root_scope" {
  command = plan
  assert {
    condition = jsondecode(aws_organizations_policy.deny_root_usage.content).Statement == [{
      Sid      = "DenyMemberRootActions"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        ArnLike = { "aws:PrincipalArn" = "arn:aws:iam::*:root" }
      }
    }]
    error_message = "Only member root principals should match; assumed admin roles must remain usable."
  }
}

run "cloudtrail_scope" {
  command = plan
  assert {
    condition = jsondecode(aws_organizations_policy.enforce_cloudtrail.content).Statement == [{
      Sid      = "DenyStoppingOrDeletingTrails"
      Effect   = "Deny"
      Action   = ["cloudtrail:StopLogging", "cloudtrail:DeleteTrail"]
      Resource = "*"
    }]
    error_message = "Protect trail stop/delete while retaining trail creation, start and read actions."
  }
}

run "mfa_scope" {
  command = plan
  assert {
    condition = jsondecode(aws_organizations_policy.require_mfa_for_console.content).Statement == [{
      Sid    = "DenyIAMUserActionsWithoutMFA"
      Effect = "Deny"
      NotAction = [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "iam:ListVirtualMFADevices",
        "iam:ResyncMFADevice",
        "sts:GetSessionToken",
      ]
      Resource = "*"
      Condition = {
        ArnLike      = { "aws:PrincipalArn" = "arn:aws:iam::*:user/*" }
        BoolIfExists = { "aws:MultiFactorAuthPresent" = "false" }
      }
    }]
    error_message = "MFA guardrail must preserve enrollment actions while denying other IAM user actions without MFA."
  }
}

run "s3_scope" {
  command = plan
  assert {
    condition = jsondecode(aws_organizations_policy.deny_public_s3.content).Statement == [{
      Sid      = "FreezeAccountPublicAccessBlock"
      Effect   = "Deny"
      Action   = "s3:PutAccountPublicAccessBlock"
      Resource = "*"
    }]
    error_message = "Freeze the account safeguard without denying private bucket policy changes needed by OAC."
  }
}
