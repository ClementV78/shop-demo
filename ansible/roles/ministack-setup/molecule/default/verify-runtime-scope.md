# Runtime Validation Boundary

This scenario verifies the Ansible role behavior only:

- the role converges on a fresh host;
- the second pass stays idempotent;
- the MiniStack container is created with the expected image and port mapping;
- the health endpoint responds on the configured port;
- the AWS CLI profile files are written as expected;
- a simple `sts get-caller-identity` smoke test works against the local endpoint.

It does not claim to prove every MiniStack-backed AWS service. The authoritative
runtime checks on the real host stay focused on the Sprint 0 acceptance scope:

- `curl http://127.0.0.1:4566/_ministack/health`
- `aws --profile ministack --endpoint-url http://127.0.0.1:4566 sts get-caller-identity`
- rerun of `ansible/playbooks/ministack-setup.yml`
