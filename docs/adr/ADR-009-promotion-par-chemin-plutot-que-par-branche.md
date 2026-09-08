# ADR-009 - Promotion par chemin et par tag, plutot que par branche d'environnement

## Statut

Accepte le 2026-09-08, pendant `S1-T5`.

Ecarte volontairement une partie de [`docs/sprint-planning.md`](../sprint-planning.md), qui prevoyait un `ApplicationSet` staging surveillant une branche `staging`.

## Contexte

`docs/sprint-planning.md` decrit pour le Sprint 1 un `ApplicationSet` staging qui surveille une branche `staging` avec deploiement au merge, et un `ApplicationSet` prod qui surveille des tags `v*.*.*`.

Deux decisions posterieures ont change le terrain. [`ADR-006`](ADR-006-structure-gitops-platform-apps-environments.md) a separe les environnements par **repertoire**, `gitops/environments/staging` et `gitops/environments/prod`. [`ADR-007`](ADR-007-gitlab-source-of-truth-github-mirror.md) a fait de `main` sur GitLab.com la source de verite unique.

Au moment d'implementer `S1-T5`, l'ecart devenait bloquant : la branche `staging` n'existe pas, et la separation des environnements est deja faite par chemin.

## Decision

Les environnements ne sont pas separes par des branches longue duree. La promotion s'appuie sur deux mecanismes differents selon la cible.

**Staging** suit `main` par chemin. Tout ce qui est merge dans `main` est deploye automatiquement dans `gitops/environments/staging` et `gitops/apps/*/overlays/staging`.

**Prod** suivra des tags semver `v*.*.*`, conformement au plan initial, ce qui reste le sujet de `S1-T6`.

Le flux complet devient :

```text
branche de feature -> merge request relue -> merge dans main
                                                  |
                                                  v
                                     staging deploie automatiquement
                                                  |
                                       tag v1.2.3 pose sciemment
                                                  v
                                          prod deploie sur le tag
```

Les branches de feature restent le mode de travail normal. Ce que cet ADR ecarte, ce sont les branches **permanentes** par environnement, pas les branches en general.

## Alternatives considerees

### 1. Branche `staging` permanente, comme prevu au plan

Avantages : modele classique, tres lisible, la promotion est un merge visible dans l'interface de la forge.

Inconvenients : deux branches longue duree divergent avec le temps. La promotion se fait par merge ou cherry-pick, et un correctif urgent applique directement sur une branche d'environnement cree une derive silencieuse que rien ne signale. Cela entre aussi en tension avec `ADR-007`, qui a fait de `main` la source de verite unique.

Decision : rejetee.

### 2. Depot GitOps separe du depot applicatif

Avantage : cycle de vie independant entre le code et l'etat desire.

Inconvenient : ajoute un depot a maintenir et une synchronisation entre les deux, pour un projet mono-depot ou `ADR-006` a deja pose une separation interne suffisante.

Decision : rejetee pour le MVP, reevaluable si les services Go grossissent.

## Consequences

Positives :

- une seule branche longue duree, donc pas de derive entre environnements ;
- les deux portes de controle sont explicites et a des endroits utiles : la relecture de merge request avant `main` donc avant staging, et la pose d'un tag avant la production ;
- coherent avec `ADR-006` et `ADR-007`, sans configuration supplementaire.

Negatives :

- la promotion vers prod n'est plus un merge visible dans la forge mais la pose d'un tag, ce qui est moins immediatement lisible pour quelqu'un qui decouvre le depot ;
- un changement fusionne dans `main` part en staging sans autre validation que la relecture de la merge request, ce qui suppose que cette relecture soit reelle ;
- l'ecart avec `docs/sprint-planning.md` doit etre maintenu explicite tant que ce document n'est pas realigne.

## Suivi

- `S1-T5` implemente l'`ApplicationSet` staging sur `main`, par chemin.
- `S1-T6` implemente la promotion prod sur tags semver.
- `docs/sprint-planning.md` decrit encore une branche `staging` pour le Sprint 1. Le realigner ou y renvoyer vers cet ADR.

Validation de cet ADR :

```bash
git diff --check
```
