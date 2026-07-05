# Repo And Learning Path

[Retour a `ARCHITECTURE.md`](../../ARCHITECTURE.md)

## Structure du repo

```text
ansible/          -> provisioning local, roles, playbooks, Molecule
bootstrap/        -> state Terraform permanent
landing-zone/     -> Organizations, SCPs, baseline AWS
platform/         -> EKS, VPC, RDS, k8s, monitoring
devsecops/        -> controles, policies, threat model
ci/               -> GitLab CI, components, OIDC
apps/shopdemo/    -> frontend, services Go, Bruno, compose
```

## Sprints

Le detail complet par sprint reste dans :

- [`../sprint-planning.md`](../sprint-planning.md)
- [`../sprints/sprint-0-ansible.md`](../sprints/sprint-0-ansible.md)
- [`../../README.md`](../../README.md)

### Vue resume

| Sprint | Sujet | Cout AWS | Lacunes adressees |
|---|---|---|---|
| 0 | Ansible + bootstrap local | 0$ + bootstrap EC2 | Ansible, Molecule, inventory |
| 1 | Argo CD et base GitOps locale | 0$ | Argo CD multi-env |
| 2 | Landing Zone AWS | ~5$/mois | Organizations, SCPs, SSO |
| 3 | Platform EKS + reseau + services AWS | ~3-5$/session | IRSA, Karpenter, WAF, Gateway API, Cognito |
| 4 | Observabilite | ~3-5$/session | PLG, Kubecost, runbooks |
| 5 | DevSecOps | ~3-5$/session | Kyverno, secrets, scans, threat model |
| 6 | CI/CD | ~3-5$/session | GitLab Components, OIDC, supply chain |

## Lacunes couvertes

| Lacune | Sprint | Niveau attendu post-projet |
|---|---|---|
| Ansible + Molecule + frontiere Terraform/Ansible | Sprint 0 | Playbooks idempotents, roles testes |
| Cilium local | Sprint 0 | Replacement mode, Hubble |
| Cilium sur EKS | Sprint 3 | Chaining mode, policies, Hubble |
| Argo CD multi-env | Sprint 1 | ApplicationSet, branching |
| Landing Zone AWS | Sprint 2 | Organizations, SCPs, SSO |
| Terraform modules custom + 2 states | Sprints 2-3 | Modules internes versionnes |
| CloudFront + WAF | Sprint 3 | CDN edge et protection L7 |
| Gateway API + JWT auth | Sprint 3 | Frontiere d'auth unique |
| Lambda webhook + API Gateway AWS | Sprint 3 | Pattern event-driven |
| SNS fan-out + SQS + idempotence | Sprint 3 | DLQ, traitement asynchrone |
| Loki / Kubecost / runbooks | Sprint 4 | Observabilite operable |
| DevSecOps shift-left | Sprint 5 | Scans, policies, digest pinning |
| GitLab Components + OIDC AWS | Sprint 6 | Zero cle IAM en CI |
