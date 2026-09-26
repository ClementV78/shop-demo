"""Check this policy's intended Deny scope, not the complete AWS IAM evaluator."""
import fnmatch
import json
from pathlib import Path
import unittest

POLICY = json.loads(
    (Path(__file__).resolve().parents[1] / "policies/deny-regions-outside-eu.json").read_text()
)


class RegionPolicyTests(unittest.TestCase):
    def test_request_matrix(self):
        statement = POLICY["Statement"][0]
        self.assertEqual(len(POLICY["Statement"]), 1)
        self.assertEqual(statement["Effect"], "Deny")
        self.assertEqual(statement["Resource"], "*")
        pattern = statement["Condition"]["StringNotLike"]["aws:RequestedRegion"]
        cases = [
            ("ec2:DescribeInstances", "eu-west-1", False),
            ("ec2:RunInstances", "eu-central-1", False),
            ("ec2:DescribeInstances", "us-east-1", True),
            ("rds:CreateDBInstance", "ap-northeast-1", True),
            ("s3:CreateBucket", "us-east-1", True),
            ("s3:PutObject", "us-east-1", True),
            ("s3:ListAllMyBuckets", "us-east-1", False),
            ("s3:GetAccountPublicAccessBlock", "us-east-1", False),
            ("iam:ListRoles", "us-east-1", False),
            ("sts:AssumeRole", "us-east-1", False),
            ("cloudfront:ListDistributions", "us-east-1", False),
            ("route53:ListHostedZones", "us-east-1", False),
            ("acm:RequestCertificate", "us-east-1", True),
            ("wafv2:CreateWebACL", "us-east-1", True),
        ]
        for action, region, expected_deny in cases:
            with self.subTest(action=action, region=region):
                exempt = any(
                    fnmatch.fnmatchcase(action.lower(), item.lower())
                    for item in statement["NotAction"]
                )
                denied = not exempt and not fnmatch.fnmatchcase(region, pattern)
                self.assertEqual(denied, expected_deny)


if __name__ == "__main__":
    unittest.main()
