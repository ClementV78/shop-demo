# Costs Risks And Evidence

[Retour a `ARCHITECTURE.md`](../../ARCHITECTURE.md)

## Exigences non fonctionnelles utiles au design

| Dimension | Cible |
|---|---|
| Criticite | Lab / demonstrateur technique |
| Disponibilite | Haute disponibilite intra-region pour montrer les patterns Multi-AZ |
| RTO | Restauration manuelle indicative < 4h |
| RPO | Backup auto + PITR, cible indicative < 24h |
| Donnees sensibles | Aucune |
| Conformite | Pas d'exigence reglementaire reelle |
| Multi-region | Non |
| Budget | ~115-185$ total projet |

## Strategie de couts AWS

<p align="center"><img src="../diagrams/couts-aws.svg" alt="Couts AWS" width="850"></p>

> 📊 **Diagramme interactif** : [`../diagrams/couts-aws.html`](../diagrams/couts-aws.html).

| Phase | Ressources actives | Cout estime | Strategie |
|---|---|---|---|
| Sprints 0-1 | Serveur Ubuntu local uniquement | 0$ | Tout en local |
| Sprint 2 | Landing Zone minimale | ~5$/mois | Permanente, posture reduite hors sessions |
| Sprints 3-6 | EKS + VPC + RDS + SQS | ~0.75-1$/h | Destroy apres session |
| **Total projet** | | **~115-185$** | |

### Decomposition horaire en session

| Ressource | Cout horaire | Notes |
|---|---|---|
| EKS control plane | $0.10/h | Cout fixe |
| 3x nodes Karpenter Spot Graviton | ~$0.25/h | Forte reduction vs On-Demand |
| RDS PostgreSQL | ~$0.03/h | t4g.micro Multi-AZ |
| Interface Endpoints | ~$0.05/h | ecr.api, ecr.dkr, sqs, secretsmanager, sts |
| NAT Gateway | ~$0.045/h | Trafic non-AWS |
| ALB | ~$0.025/h | LB controller |
| CloudFront + WAF | ~$0.01/h | Faible trafic |
| CloudWatch Logs | ~$0.02/h | Ingestion + retention courte |

## NAT Gateway vs VPC Endpoints

Les `VPC Endpoints` couvrent le trafic AWS-to-AWS. Le `NAT Gateway` reste necessaire pour le trafic non-AWS : registries publiques, dependances externes, GitLab/GitHub, OCSP/CRL, APIs externes.

## Risques assumes

| Risque | Acceptation | Mitigation |
|---|---|---|
| Pas de multi-region | Accepte | IaC reconstructible dans une autre region |
| GuardDuty/Config CIS intermittents hors session | Accepte | Budgets + Cost Anomaly Detection actifs |
| EKS disproportionne pour ShopDemo | Accepte | Objectif pedagogique platform engineering |
| Spot interruption | Accepte | PDB, HPA, fallback on-demand documente |
| NAT Gateway conserve | Accepte | Gain trop faible vs perte de flexibilite |
| Thumbprint OIDC statique | Accepte | Verification annuelle documentee |

## Matrice de preuves - controles critiques

| Controle | Preuve attendue | Sprint |
|---|---|---|
| RDS chiffre + backup + PITR teste | Module `rds-postgres`, restore documente | Sprint 3 |
| IRSA - pas de credentials node sur les pods | Module `irsa-role`, annotations SA | Sprint 3 |
| IMDSv2 enforced | `EC2NodeClass.metadataOptions.httpTokens: required` | Sprint 3 |
| Control plane EKS - logs complets | `enabled_cluster_log_types`, CloudWatch Logs | Sprint 3 |
| DLQ par queue + idempotence | Module `sns-fanout`, `processed_events`, alerte | Sprint 3/4 |
| Secrets jamais en clair | ESO + Secrets Manager | Sprint 3/5 |
| Images digest-pinned | GitOps `@sha256:`, policy Kyverno | Sprint 5/6 |
| Admission control runtime | Policies `Kyverno` | Sprint 5 |
| SCPs testees avant application | Plan sandbox, doc services globaux | Sprint 2 |
| OIDC GitLab scope project/branch | Module `gitlab-oidc` | Sprint 6 |
| EKS Access Entries scopees namespace | `aws_eks_access_policy_association` | Sprint 6 |
| Runbooks par alerte critique | `monitoring/runbooks/*.md` | Sprint 4 |
