# Runtime Validation Boundary

This scenario verifies the Ansible role behavior only:

- the role converges on a fresh host;
- the second pass stays idempotent;
- the Helm release is created with the expected values;
- the expected Kubernetes objects are rendered into the cluster.

It does not claim to prove the full Cilium datapath inside Docker. The
authoritative runtime checks stay on the real host:

- `cilium status --wait`
- `cilium connectivity test`
- Hubble relay/UI health
- rerun of `ansible/playbooks/cilium-setup.yml`
