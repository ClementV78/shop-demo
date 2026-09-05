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
| S1-T1 | Cadrer la structure GitOps locale | Planifie | S0 |
| S1-T2 | Installer Argo CD sur le lab local | Planifie | S1-T1 |
| S1-T3 | Definir les namespaces et NetworkPolicies de base | Planifie | S1-T1 |
| S1-T4 | Creer les manifests applicatifs minimaux | Planifie | S1-T1 |
| S1-T5 | Ajouter ApplicationSet staging | Planifie | S1-T2, S1-T4 |
| S1-T6 | Ajouter ApplicationSet prod base sur tags | Planifie | S1-T5 |
| S1-T7 | Documenter usage, rollback et depannage GitOps | Planifie | S1-T5 |

## Cadrage initial

Sprint non demarre. Le Sprint 0 est clos ; le demarrage peut commencer par
`S1-T1`, apres commit du lot de cloture.

Hypotheses de depart :

- le cluster local `k3s` existe deja et Cilium est operationnel ;
- les routes Cloudflare vers `argocd`, `grafana` et `gitea` restent raccordees
  seulement quand les origins locales existent reellement ;
- les secrets restent hors Git et seront injectes via une source externe ou un
  mecanisme documente pendant le sprint ;
- les manifests doivent rester simples au depart pour valider le flux GitOps
  avant d'ajouter des patterns avances.

## Preuves

| Controle | Etat | Preuve |
|---|---|---|
| Plan de sprint | Planifie | Fichier de suivi cree |
| Installation Argo CD | Planifie | A renseigner |
| Sync GitOps staging | Planifie | A renseigner |
| Rollback GitOps | Planifie | A renseigner |

## Decisions et ecarts

Aucun ecart identifie a ce stade. Les decisions structurantes seront ajoutees
pendant le sprint si elles depassent le simple choix d'implementation locale.
