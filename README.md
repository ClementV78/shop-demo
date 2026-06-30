# IDP Platform — ShopDemo

> Une Internal Developer Platform construite de zéro, du serveur Ubuntu
> local jusqu'à une architecture cible AWS multi-comptes — pour démontrer,
> en conditions réelles, les compétences DevOps/Cloud Architecture senior.

Ce dépôt documente la construction complète d'une plateforme de
déploiement interne autour de **ShopDemo**, une application e-commerce de
démonstration volontairement simple côté métier : chaque brique
d'infrastructure existe pour une raison technique précise, pas par
accumulation.

## Pourquoi ce projet

Plutôt qu'une suite d'exercices isolés, ce projet relie Terraform, Ansible,
Kubernetes, CI/CD, observabilité et sécurité dans **un seul système
cohérent**, justifié de bout en bout par un cas d'usage fonctionnel :
inscription, catalogue, panier, commande, paiement simulé.

| Compétence | Ce qui est démontré |
|---|---|
| Landing Zone AWS | Organizations, SCPs, IAM Identity Center, multi-compte |
| Kubernetes | k3s local et EKS cible, Cilium, Gateway API, GitOps avec Argo CD |
| Infrastructure as Code | Modules Terraform internes versionnés, Ansible idempotent testé Molecule |
| CI/CD | GitLab CI Components, OIDC vers AWS, digest pinning, pas de clé statique |
| Observabilité | Prometheus, Loki, Grafana, Kubecost |
| DevSecOps | Scans Trivy/OWASP/GitLeaks, admission control Kyverno, shift-left |
| FinOps | Infra 100% éphémère, Spot/Graviton, `terraform destroy` systématique |

## Aperçu du flux applicatif

```mermaid
flowchart LR
    U([Utilisateur]) --> CF[CloudFront + WAF]
    CF --> S3[(S3 — frontend statique)]
    CF --> GW[Gateway API NGINX]
    GW --> SVC[Microservices Go sur EKS]
    SVC --> RDS[(RDS PostgreSQL)]
    SVC --> SNS[[SNS fan-out]]
    SNS --> SQS1[(SQS queue-stock)]
    SNS --> SQS2[(SQS queue-notification)]
    APIGW[API Gateway] --> LBD[Lambda webhook-paiement]
    LBD --> SNS
```

Le détail complet — séquence d'appels, justification de chaque service AWS,
exigences non fonctionnelles — vit dans [`ARCHITECTURE.md`](ARCHITECTURE.md),
qui fait foi sur la conception cible.

## Où en est le projet

Le projet avance sprint par sprint, avec un suivi versionné dans `docs/`.
État courant et prochaine action : [`docs/CURRENT.md`](docs/CURRENT.md).
Vue globale de la progression : [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Démarrer ici

| Lien | Contenu |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Conception cible, stack, arbitrages |
| [`AGENTS.md`](AGENTS.md) | Règles de travail pour les agents IA du dépôt |
| [`docs/CURRENT.md`](docs/CURRENT.md) | Sprint actif et tâches en cours |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Vue globale des sprints |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Règles de suivi et de documentation |
| [`docs/README.md`](docs/README.md) | Index complet de la documentation |
| [`LEARNING.md`](LEARNING.md) | Notions apprises au fil des sprints |

## Structure du dépôt

```
.
├── ansible/   # Provisioning et configuration des hôtes (k3s, Cilium, runners, hardening)
├── docs/      # Suivi de projet : sprints, ADR, preuves
├── AGENTS.md, ARCHITECTURE.md, LEARNING.md
```

---

Ce dépôt est un laboratoire d'apprentissage et un portfolio personnel, pas un
projet en production commerciale — voir les exigences non fonctionnelles
dans [`ARCHITECTURE.md`](ARCHITECTURE.md#exigences-non-fonctionnelles-cibles)
pour le détail des compromis assumés.
