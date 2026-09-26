"""Contract examples for the supported SCP statements, not a full IAM simulator."""
import fnmatch
import json
from pathlib import Path
import unittest

POLICIES = Path(__file__).resolve().parents[1] / "policies"


def denied(name, action, principal, mfa=None):
    statement = json.loads((POLICIES / f"{name}.json").read_text())["Statement"][0]
    if "Action" in statement:
        actions = statement["Action"]
        if isinstance(actions, str):
            actions = [actions]
        if not any(fnmatch.fnmatchcase(action.lower(), pattern.lower()) for pattern in actions):
            return False
    else:
        exceptions = statement["NotAction"]
        if isinstance(exceptions, str):
            exceptions = [exceptions]
        if any(fnmatch.fnmatchcase(action.lower(), pattern.lower()) for pattern in exceptions):
            return False
    conditions = statement.get("Condition", {})
    pattern = conditions.get("ArnLike", {}).get("aws:PrincipalArn")
    if pattern is not None and not fnmatch.fnmatchcase(principal, pattern):
        return False
    if "BoolIfExists" in conditions and mfa is True:
        return False
    return statement["Effect"] == "Deny"


class GuardrailTests(unittest.TestCase):
    def test_identity_and_action_matrix(self):
        user = "arn:aws:iam::000000000000:user/tester"
        role = "arn:aws:iam::000000000000:role/OrganizationAccountAccessRole"
        root = "arn:aws:iam::000000000000:root"
        cases = [
            ("deny-root-usage", "ec2:DescribeInstances", root, None, True),
            ("deny-root-usage", "ec2:DescribeInstances", role, None, False),
            ("require-mfa-for-console", "ec2:DescribeInstances", user, False, True),
            ("require-mfa-for-console", "ec2:DescribeInstances", user, None, True),
            ("require-mfa-for-console", "ec2:DescribeInstances", user, True, False),
            ("require-mfa-for-console", "ec2:DescribeInstances", role, None, False),
            ("require-mfa-for-console", "iam:CreateVirtualMFADevice", user, False, False),
            ("require-mfa-for-console", "iam:EnableMFADevice", user, False, False),
            ("require-mfa-for-console", "sts:GetSessionToken", user, False, False),
            ("require-mfa-for-console", "iam:DeleteVirtualMFADevice", user, False, True),
            ("deny-iam-longterm-keys", "iam:CreateAccessKey", role, None, True),
            ("deny-iam-longterm-keys", "iam:DeleteAccessKey", role, None, False),
            ("deny-iam-longterm-keys", "sts:AssumeRole", role, None, False),
            ("enforce-cloudtrail", "cloudtrail:StopLogging", role, None, True),
            ("enforce-cloudtrail", "cloudtrail:DeleteTrail", role, None, True),
            ("enforce-cloudtrail", "cloudtrail:StartLogging", role, None, False),
            ("enforce-cloudtrail", "cloudtrail:GetTrailStatus", role, None, False),
            ("deny-public-s3", "s3:PutAccountPublicAccessBlock", role, None, True),
            ("deny-public-s3", "s3:GetAccountPublicAccessBlock", role, None, False),
            ("deny-public-s3", "s3:PutBucketPolicy", role, None, False),
        ]
        for name, action, principal, mfa, expected in cases:
            with self.subTest(policy=name, action=action, principal=principal, mfa=mfa):
                self.assertEqual(denied(name, action, principal, mfa), expected)


if __name__ == "__main__":
    unittest.main()
