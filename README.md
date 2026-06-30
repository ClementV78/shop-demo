# IDP Platform — ShopDemo

Projet personnel de montée en compétences DevOps/Cloud Architecture : une
Internal Developer Platform construite autour de **ShopDemo**, une
application e-commerce de démonstration, auto-hébergée sur serveur Ubuntu
local avec une architecture cible AWS multi-comptes.

La conception cible (frontend S3/CloudFront/WAF, microservices Go sur EKS,
RDS, fan-out SNS/SQS, webhook de paiement API Gateway/Lambda, Cognito,
Terraform, Ansible, GitOps) est documentée dans
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## Démarrer ici

- [`AGENTS.md`](AGENTS.md) — règles de travail pour les agents IA du dépôt.
- [`docs/CURRENT.md`](docs/CURRENT.md) — sprint actif et tâches en cours.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — vue globale des sprints.
- [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) — règles de suivi et de
  documentation.
- [`docs/README.md`](docs/README.md) — index complet de la documentation.

## Structure du dépôt

| Répertoire | Contenu |
|---|---|
| `ansible/` | Provisioning et configuration des hôtes (k3s, Cilium, runners, hardening) |
| `docs/` | Suivi de projet, sprints, ADR, preuves |
| `LEARNING.md` | Notions apprises au fil des sprints |

Ce dépôt est un laboratoire et un portfolio personnel, pas un projet en
production commerciale.
