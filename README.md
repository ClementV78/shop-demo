<div align="center">

# IDP Platform : ShopDemo

**Internal Developer Platform construite from scratch, du serveur Ubuntu local à une architecture cible AWS multi-comptes.**

*Un projet portfolio orienté Platform Engineering : bootstrap local reproductible aujourd'hui, architecture AWS/EKS/GitOps cible documentée et versionnée.*

![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white) ![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white) ![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat-square&logo=ansible&logoColor=white) ![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white) ![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat-square&logo=amazonaws&logoColor=white)

[Pourquoi ce projet](#pourquoi-ce-projet) · [Comprendre](docs/comprendre-le-projet.md) · [Comment ça marche](docs/comment-ca-marche.md) · [Glossaire](docs/glossaire.md) · [Architecture](#aperçu-du-flux-applicatif) · [Compétences démontrées](#compétences-démontrées) · [Quick start](#quick-start) · [Où en est le projet](#où-en-est-le-projet) · [Démarrer ici](#démarrer-ici)

</div>

<p align="center">
  <img src="docs/diagrams/readme-overview.svg" alt="Vue d'ensemble ShopDemo" width="1100">
</p>

---

## Pourquoi ce projet

Plutôt qu'une suite d'exercices isolés, ce projet relie Terraform, Ansible, Kubernetes, CI/CD, observabilité et sécurité dans **un seul système cohérent**, construit autour de **ShopDemo**, une application e-commerce de démonstration volontairement simple côté métier. L'objectif : que chaque brique d'infrastructure se justifie par un besoin fonctionnel réel (inscription, catalogue, panier, commande, paiement simulé), pas par accumulation de technologies.

## Ce que montre le dépôt

- **Déjà en place** : bootstrap local `Ansible + k3s + Cilium + MiniStack`, avec idempotence et tests ciblés.
- **Architecture cible** : AWS multi-comptes, EKS, Gateway API, Cognito, RDS, SNS/SQS, Argo CD et GitOps.
- **Cadrage agentique** : un MVP centre sur une requete `prompt/agentic`, avec scenarios reserves aux tests et sans mode `live`.
- **Documentation de travail** : roadmap, arbitrages, preuves et deep dives versionnés dans le dépôt.

## Aperçu du flux applicatif

> Le détail complet (séquence d'appels, justification de chaque service AWS, exigences non fonctionnelles) vit dans [`ARCHITECTURE.md`](ARCHITECTURE.md), qui fait foi sur la conception cible.

## Compétences démontrées

| Domaine | Ce qui est mis en œuvre |
|---|---|
| **Landing Zone AWS** | Organizations, SCPs, IAM Identity Center, multi-compte |
| **Kubernetes** | k3s local et EKS cible, Cilium, Gateway API, GitOps avec Argo CD |
| **Infrastructure as Code** | Modules Terraform internes versionnés, Ansible idempotent testé Molecule |
| **CI/CD** | GitLab CI Components, OIDC vers AWS, digest pinning, aucune clé statique |
| **Observabilité** | Prometheus, Loki, Grafana, Kubecost |
| **DevSecOps** | Scans Trivy / OWASP / GitLeaks, admission control Kyverno, shift-left |
| **FinOps** | Infra 100 % éphémère, Spot/Graviton, `terraform destroy` systématique |

## Quick start

Pour le parcours complet, y compris les frontieres entre actions manuelles et automatisation Terraform, suivre le [manuel d'installation de la plateforme](docs/installation.md).

Ce qui existe aujourd'hui : un bootstrap local reproductible autour d'Ansible,
avec les roles `k3s-install`, `cilium-setup`, `ministack-setup`,
`cloudflare-tunnel` et `gitlab-runner`, puis une premiere structure GitOps
locale dans [`gitops/`](gitops/). Les validations reelles vont jusqu'au
service `gitlab-runner` actif sur l'hote local, a son enregistrement sur
`GitLab.com`, puis a un pipeline de smoke passe sur la branche
`test/gitlab-runner-smoke`. Le reste de la plateforme AWS/EKS applicative
arrive sprint par sprint.

```bash
git clone https://gitlab.com/ClementV78/shopdemo.git
cd shop-demo/ansible

# Installer les collections requises
ansible-galaxy collection install -r requirements.yml

# Installer k3s puis Cilium sur l'hôte local (sudo requis)
ansible-playbook playbooks/k3s-install.yml --ask-become-pass
ansible-playbook playbooks/cilium-setup.yml --ask-become-pass
ansible-playbook playbooks/ministack-setup.yml --ask-become-pass

# Rejouer les roles en isolation, avec tests d'idempotence (Molecule + Docker)
cd roles/k3s-install
molecule test

cd ../cilium-setup
molecule test
```

GitLab.com est la source de verite pour le developpement, la CI/CD et GitOps.
GitHub reste un miroir public en lecture seule pour le portfolio.

Les roles `cloudflare-tunnel` et `gitlab-runner` existent aussi, mais demandent des secrets externes non versionnes (`TUNNEL_TOKEN`, token runner GitLab) et ne font donc pas partie du chemin "copier-coller" ci-dessus. Le reste de la plateforme (Terraform, EKS, CI/CD complet) arrive sprint après sprint, voir [Où en est le projet](#où-en-est-le-projet).

## Où en est le projet

Le projet avance sprint par sprint, avec un suivi versionné dans `docs/`.

![Sprint 0](https://img.shields.io/badge/S0_Ansible-Terminé-green?style=flat-square) ![Sprint 1](https://img.shields.io/badge/S1_ArgoCD_%2B_GitOps_local-Terminé-green?style=flat-square) ![Sprint 2](https://img.shields.io/badge/S2_Landing_Zone-En_cours-blue?style=flat-square) ![Sprint 3](https://img.shields.io/badge/S3_EKS-Planifié-lightgrey?style=flat-square) ![Sprint 4](https://img.shields.io/badge/S4_Observabilité-Planifié-lightgrey?style=flat-square) ![Sprint 5](https://img.shields.io/badge/S5_DevSecOps-Planifié-lightgrey?style=flat-square) ![Sprint 6](https://img.shields.io/badge/S6_CI%2FCD-Planifié-lightgrey?style=flat-square)

| | |
|---|---|
| Sprint actif | `Sprint 2` : Landing Zone AWS. Organization, comptes, SCPs sandbox, IAM Identity Center et baseline permanente deployes |
| Suivi détaillé | [`docs/CURRENT.md`](docs/CURRENT.md) |

| Sprint | Sujet | État | Fichier de suivi |
|---|---|---|---|
| 0 | Ansible et fondations bootstrap | Terminé | [`sprint-0-ansible.md`](docs/sprints/sprint-0-ansible.md) |
| 1 | Argo CD et base GitOps locale | Terminé | [`sprint-1-gitops-local.md`](docs/sprints/sprint-1-gitops-local.md) |
| 2 | Landing Zone AWS | En cours | [`sprint-2-landing-zone.md`](docs/sprints/sprint-2-landing-zone.md) |
| 3 | Plateforme AWS et EKS | Planifié | À créer avant démarrage |
| 4 | Observabilité | Planifié | À créer avant démarrage |
| 5 | DevSecOps | Planifié | À créer avant démarrage |
| 6 | CI/CD et GitOps | Planifié | À créer avant démarrage |

Règles de progression : un seul sprint `En cours` à la fois ; le prochain sprint est détaillé pendant la clôture du courant ; un sprint passe à `Terminé` lorsque ses livrables et validations obligatoires sont documentés dans son fichier de suivi.

**Focus courant** : `Sprint 1` est terminé. La chaîne GitOps complète
fonctionne sur le lab local : un merge dans `main` déploie automatiquement
staging, et seule la pose d'un tag semver promeut en production. Le rollback a
été exécuté sur un incident réel, pas seulement décrit. Voir le
[guide d'exploitation](docs/exploitation-gitops.md).

Le `Sprint 2` est en cours : le state Terraform `bootstrap`, l'Organization, les trois OUs, les quatre comptes membres et les six SCPs attachees au sandbox sont deployes. La policy regionale et la protection S3 ont ete validees sur AWS. IAM Identity Center est deploye et valide par une ecriture SSM autorisee avec `DevAccess` dans sandbox, puis refusee avec `ReadOnly` dans workload-prod. La baseline permanente est aussi deployee : CloudTrail organisationnel, AWS Config dans les comptes membres, bucket d'audit central, budgets et Cost Anomaly Detection. Ses preuves fonctionnelles restent a produire avant S2-T7, l'authentification GitLab OIDC. Le detail, les couts estimes et les limites de reversibilite vivent dans [`sprint-2-landing-zone.md`](docs/sprints/sprint-2-landing-zone.md).

## Démarrer ici

| Lien | Contenu |
|---|---|
| [`docs/installation.md`](docs/installation.md) | Manuel d'installation vivant : lab local, bootstrap AWS, actions manuelles et automatisation |
| [`docs/comprendre-le-projet.md`](docs/comprendre-le-projet.md) | Vision globale, etat actuel, chemin cible et pitch entretien |
| [`docs/comment-ca-marche.md`](docs/comment-ca-marche.md) | Explication technique progressive : comment les sprints sont construits dans le code |
| [`docs/glossaire.md`](docs/glossaire.md) | Definitions courtes : Cilium, Hubble, CoreDNS, Terraform, GitOps, AWS, etc. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Conception cible, stack, arbitrages |
| [`docs/architecture/08-agentic-mvp.md`](docs/architecture/08-agentic-mvp.md) | MVP agentique, separation produit/tests |
| [`docs/gitops-structure.md`](docs/gitops-structure.md) | Structure GitOps locale, conventions et validations |
| [`docs/concepts-sprint-1.md`](docs/concepts-sprint-1.md) | Concepts GitOps/Argo CD du Sprint 1 |
| [`docs/sprint-planning.md`](docs/sprint-planning.md) | Détail des objectifs et livrables par sprint |
| [`AGENTS.md`](AGENTS.md) | Règles de travail pour les agents IA du dépôt |
| [`docs/CURRENT.md`](docs/CURRENT.md) | Sprint actif et tâches en cours |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Règles de suivi et de documentation |
| [`docs/README.md`](docs/README.md) | Index complet de la documentation |
| [`LEARNING.md`](LEARNING.md) | Notions apprises au fil des sprints |

## Structure du dépôt

```text
.
├── ansible/     # Provisioning et configuration des hôtes (k3s, Cilium, runners, hardening)
├── terraform/   # Infrastructure AWS : state bootstrap permanent, modules, state workload éphémère
├── gitops/      # État Kubernetes désiré, synchronisé par Argo CD
├── docs/        # Suivi de projet : sprints, ADR, preuves, schémas
├── AGENTS.md
├── ARCHITECTURE.md
└── LEARNING.md
```

Les trois répertoires d'infrastructure suivent la même règle : `terraform/` provisionne, `ansible/` configure, `gitops/` décrit l'état désiré du cluster. Aucun ne fait le travail d'un autre.

---

<div align="center">

Laboratoire d'apprentissage et portfolio personnel, pas un projet en production commerciale. Voir les [exigences non fonctionnelles](ARCHITECTURE.md#exigences-non-fonctionnelles-cibles) pour le détail des compromis assumés.

</div>
