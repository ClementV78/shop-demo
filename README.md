<div align="center">

# IDP Platform : ShopDemo

**Internal Developer Platform construite from scratch, du serveur Ubuntu local à une architecture cible AWS multi-comptes.**

*Un projet portfolio orienté Platform Engineering : bootstrap local reproductible aujourd'hui, architecture AWS/EKS/GitOps cible documentée et versionnée.*

![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white) ![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white) ![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat-square&logo=ansible&logoColor=white) ![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white) ![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat-square&logo=amazonaws&logoColor=white)

[Pourquoi ce projet](#pourquoi-ce-projet) · [Architecture](#aperçu-du-flux-applicatif) · [Compétences démontrées](#compétences-démontrées) · [Quick start](#quick-start) · [Où en est le projet](#où-en-est-le-projet) · [Démarrer ici](#démarrer-ici)

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

Ce qui existe aujourd'hui (Sprint 0) : un bootstrap local reproductible autour d'Ansible, avec les roles `k3s-install`, `cilium-setup` et `ministack-setup`. `S0-T7` est termine : MiniStack est valide localement avec `health` et `sts get-caller-identity`, plus un second passage idempotent. C'est aujourd'hui le seul chemin exécutable de bout en bout dans le dépôt ; le reste de la plateforme AWS/EKS/CI-CD arrive sprint par sprint.

```bash
git clone https://github.com/ClementV78/shop-demo.git
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

Le reste de la plateforme (Terraform, EKS, CI/CD) arrive sprint après sprint, voir [Où en est le projet](#où-en-est-le-projet).

## Où en est le projet

Le projet avance sprint par sprint, avec un suivi versionné dans `docs/`.

![Sprint 0](https://img.shields.io/badge/S0_Ansible-En_cours-yellow?style=flat-square) ![Sprint 1](https://img.shields.io/badge/S1_ArgoCD_%2B_GitOps_local-Planifié-lightgrey?style=flat-square) ![Sprint 2](https://img.shields.io/badge/S2_Landing_Zone-Planifié-lightgrey?style=flat-square) ![Sprint 3](https://img.shields.io/badge/S3_EKS-Planifié-lightgrey?style=flat-square) ![Sprint 4](https://img.shields.io/badge/S4_Observabilité-Planifié-lightgrey?style=flat-square) ![Sprint 5](https://img.shields.io/badge/S5_DevSecOps-Planifié-lightgrey?style=flat-square) ![Sprint 6](https://img.shields.io/badge/S6_CI%2FCD-Planifié-lightgrey?style=flat-square)

| | |
|---|---|
| Sprint actif | `Sprint 0` : Ansible et fondations bootstrap |
| Suivi détaillé | [`docs/CURRENT.md`](docs/CURRENT.md) |

| Sprint | Sujet | État | Fichier de suivi |
|---|---|---|---|
| 0 | Ansible et fondations bootstrap | En cours | [`sprint-0-ansible.md`](docs/sprints/sprint-0-ansible.md) |
| 1 | Argo CD et base GitOps locale | Planifié | À créer avant démarrage |
| 2 | Landing Zone AWS | Planifié | À créer avant démarrage |
| 3 | Plateforme AWS et EKS | Planifié | À créer avant démarrage |
| 4 | Observabilité | Planifié | À créer avant démarrage |
| 5 | DevSecOps | Planifié | À créer avant démarrage |
| 6 | CI/CD et GitOps | Planifié | À créer avant démarrage |

Règles de progression : un seul sprint `En cours` à la fois ; le prochain sprint est détaillé pendant la clôture du courant ; un sprint passe à `Terminé` lorsque ses livrables et validations obligatoires sont documentés dans son fichier de suivi.

**Focus courant du sprint** : `S0-T8` est termine. La suite logique du Sprint 0 est `S0-T9` puis `S0-T10`, avant la composition finale de `bootstrap.yml` / `teardown.yml`.

## Démarrer ici

| Lien | Contenu |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Conception cible, stack, arbitrages |
| [`docs/sprint-planning.md`](docs/sprint-planning.md) | Détail des objectifs et livrables par sprint |
| [`AGENTS.md`](AGENTS.md) | Règles de travail pour les agents IA du dépôt |
| [`docs/CURRENT.md`](docs/CURRENT.md) | Sprint actif et tâches en cours |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Règles de suivi et de documentation |
| [`docs/README.md`](docs/README.md) | Index complet de la documentation |
| [`LEARNING.md`](LEARNING.md) | Notions apprises au fil des sprints |

## Structure du dépôt

```text
.
├── ansible/   # Provisioning et configuration des hôtes (k3s, Cilium, runners, hardening)
├── docs/      # Suivi de projet : sprints, ADR, preuves
├── AGENTS.md
├── ARCHITECTURE.md
└── LEARNING.md
```

---

<div align="center">

Laboratoire d'apprentissage et portfolio personnel, pas un projet en production commerciale. Voir les [exigences non fonctionnelles](ARCHITECTURE.md#exigences-non-fonctionnelles-cibles) pour le détail des compromis assumés.

</div>
