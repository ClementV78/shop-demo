# Sprint 1 - Argo CD et base GitOps locale

## Objectif

Mettre en place une base GitOps locale au-dessus du cluster `k3s + Cilium`
livre au Sprint 0, avec Argo CD, des manifests Kubernetes versionnes et une
separation claire entre environnements de test.

Conception cible :
[`docs/sprint-planning.md - Sprint 1`](../sprint-planning.md#sprint-1--argo-cd-et-base-gitops-locale).

## Tableau de bord

| ID | Tache | Etat | Depend de |
|---|---|---|---|
| S1-T1 | Cadrer la structure GitOps locale | Termine | S0 |
| S1-T2 | Installer Argo CD sur le lab local | Planifie | S1-T1 |
| S1-T3 | Definir les namespaces et NetworkPolicies de base | Planifie | S1-T1 |
| S1-T4 | Creer les manifests applicatifs minimaux | Planifie | S1-T1 |
| S1-T5 | Ajouter ApplicationSet staging | Planifie | S1-T2, S1-T4 |
| S1-T6 | Ajouter ApplicationSet prod base sur tags | Planifie | S1-T5 |
| S1-T7 | Documenter usage, rollback et depannage GitOps | Planifie | S1-T5 |

## Cadrage initial

Sprint demarre le 2026-09-06.

Hypotheses de depart :

- le cluster local `k3s` existe deja et Cilium est operationnel ;
- les routes Cloudflare vers `argocd` et `grafana` restent raccordees
  seulement quand les origins locales existent reellement ;
- les secrets restent hors Git et seront injectes via une source externe ou un
  mecanisme documente pendant le sprint ;
- les manifests doivent rester simples au depart pour valider le flux GitOps
  avant d'ajouter des patterns avances.

## S1-T1 - Cadrer la structure GitOps locale

Etat : `Termine`.

Objectif : creer une base GitOps lisible, validable localement, sans installer
Argo CD ni appliquer de ressource sur le cluster.

Livrables :

- arborescence [`../../gitops/`](../../gitops/) creee ;
- separation `platform/`, `apps/`, `environments/` et `argocd/` ;
- namespaces transverses `argocd` et `gateway-system` dans
  `gitops/platform/` ;
- namespaces applicatifs `shopdemo-staging` et `shopdemo-prod` separes par
  environnement ;
- document de reference [`../gitops-structure.md`](../gitops-structure.md) ;
- document pedagogique [`../concepts-sprint-1.md`](../concepts-sprint-1.md) ;
- document transverse [`../comment-ca-marche.md`](../comment-ca-marche.md), mis
  a jour avec Sprint 0 et `S1-T1` ;
- trois schemas Draw.io ajoutes au catalogue.

Ce qui n'a volontairement pas ete fait :

- pas d'installation Argo CD ;
- pas de `kubectl apply` ;
- pas de `ApplicationSet` ;
- pas de NetworkPolicy ;
- pas de secret ni token GitOps.

Raison : `S1-T1` doit d'abord rendre le modele lisible et validable. Les
objets qui modifient le cluster arrivent a partir de `S1-T2`.

## Preuves

| Controle | Etat | Preuve |
|---|---|---|
| Plan de sprint | Verifie | Fichier de suivi mis a jour |
| Structure GitOps | Verifie | `gitops/` cree avec separation plateforme/app/environnements |
| Render Kustomize plateforme | Verifie | `kubectl kustomize gitops/platform` |
| Render Kustomize staging | Verifie | `kubectl kustomize gitops/environments/staging` |
| Render Kustomize prod | Verifie | `kubectl kustomize gitops/environments/prod` |
| Validation YAML GitOps | Verifie | `yamllint gitops` |
| Validation schemas Kubernetes | Verifie | `kubeconform -strict -ignore-missing-schemas` sur les rendus Kustomize |
| Schemas Draw.io | Verifie | `validate.py --score` OK et exports SVG generes |
| Installation Argo CD | Planifie | A renseigner |
| Sync GitOps staging | Planifie | A renseigner |
| Rollback GitOps | Planifie | A renseigner |

## Decisions et ecarts

- Decision : `platform/` est synchronise separement des environnements
  applicatifs. Cela evite qu'une app staging porte par accident des ressources
  globales du cluster ou des objets prod.
- Decision : `S1-T1` reste sans effet de bord runtime. Les validations sont
  limitees au rendu local et aux schemas.
- Decision : la forge Git self-hosted sort de la cible MVP GitOps via
  `ADR-002`. Le repo GitOps cible est `GitLab.com`, source de verite, avec
  `GitHub` en miroir public (`ADR-007`).
- Ecart accepte : la convention cible parle d'`ApplicationSet`, mais aucun
  objet Argo CD n'est encore cree. C'est reporte a `S1-T2` pour garder le
  premier lot simple et explicable.

## Prochaine etape

`S1-T2` : installer Argo CD sur le lab local, documenter l'acces, puis valider
que le control plane GitOps est sain avant de lui confier des applications.
