# Roadmap IDP Platform

Source de verite de la conception : [`ARCHITECTURE.md`](../ARCHITECTURE.md).

## Vue globale

| Sprint | Sujet | Etat | Fichier de suivi |
|---|---|---|---|
| 0 | Ansible et fondations bootstrap | En cours | [`sprint-0-ansible.md`](sprints/sprint-0-ansible.md) |
| 1 | k3s, Cilium et Argo CD | Planifie | A creer avant demarrage |
| 2 | Landing Zone AWS | Planifie | A creer avant demarrage |
| 3 | Plateforme AWS et EKS | Planifie | A creer avant demarrage |
| 4 | Observabilite | Planifie | A creer avant demarrage |
| 5 | DevSecOps | Planifie | A creer avant demarrage |
| 6 | CI/CD et GitOps | Planifie | A creer avant demarrage |

## Regles de progression

- Un seul sprint est `En cours` par defaut.
- Le prochain sprint est detaille pendant la cloture du sprint courant.
- Un sprint est `Termine` lorsque ses livrables et validations obligatoires sont
  documentes dans son fichier de suivi.

## Prochain jalon

Obtenir un role Ansible `k3s-install` reproductible, teste et idempotent, puis
installer Cilium dans un second temps.
