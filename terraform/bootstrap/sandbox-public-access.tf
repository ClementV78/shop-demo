resource "aws_s3_account_public_access_block" "sandbox" {
  provider   = aws.sandbox
  account_id = module.organization.account_ids["sandbox"]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle {
    prevent_destroy = true
  }
}
