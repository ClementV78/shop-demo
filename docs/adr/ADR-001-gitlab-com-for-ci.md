# ADR-001 - Utiliser GitLab.com pour la CI

## Statut

Accepte.

Partiellement supersede par
[`ADR-002`](ADR-002-remove-gitea-from-mvp.md) pour la partie GitOps
self-hosted.

## Contexte

Le projet doit mettre en place un role Ansible `gitlab-runner` pendant le
Sprint 0, puis une CI/CD complete avec `GitLab Components`, `OIDC` vers AWS,
shared runners et runner bootstrap prive au Sprint 6.

Une ambiguite restait ouverte :

- utiliser `GitLab.com` pour la CI/CD ;
- ou operer une instance GitLab self-hosted pour la forge et la CI.

Cette decision impacte :

- le role `gitlab-runner` du Sprint 0 ;
- la demonstration future de `OIDC -> AWS` ;
- la charge d'exploitation du lab ;
- la lisibilite du portfolio.

L'architecture cible de reference mentionne :

- des shared runners `GitLab.com` pour `apply/destroy workload` ;
- un runner bootstrap prive pour les jobs necessitant le reseau VPC.

References :

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md)
- [`docs/architecture/02-aws-target.md`](../architecture/02-aws-target.md)
- [`docs/architecture/05-delivery-gitops.md`](../architecture/05-delivery-gitops.md)
- [`docs/sprint-planning.md`](../sprint-planning.md)

## Decision

Le projet utilise `GitLab.com` comme plateforme CI/CD de reference.

Le projet n'opere pas d'instance GitLab auto-hebergee.

Le role Ansible `gitlab-runner` sera donc concu pour :

- cibler `https://gitlab.com` par defaut ;
- rester parametrable via variable pour une URL GitLab differente si besoin ;
- rester reutilisable sans fork entre serveur local et EC2 bootstrap ;
- externaliser tout secret ou token hors du depot.

## Alternatives considerees

### 1. GitLab self-hosted pour toute la CI/CD

Avantages :

- autonomie complete sur la forge et les runners ;
- apprentissage supplementaire de l'exploitation GitLab.

Inconvenients :

- forte charge d'exploitation supplementaire : upgrades, stockage, TLS,
  sauvegardes, observabilite, securite ;
- complexite qui n'apporte pas beaucoup a l'objectif principal du projet ;
- brouille le message portfolio, qui vise surtout AWS, DevOps, Kubernetes et
  architectures agentiques, pas l'administration GitLab.

Decision : rejetee.

### 2. GitLab.com pour la CI et aucune composante self-hosted Git

Avantages :

- simplification maximale.

Decision : finalement acceptee pour le MVP GitOps via
[`ADR-002`](ADR-002-remove-gitea-from-mvp.md).

## Consequences

Positives :

- meilleur alignement avec la demonstration future de `OIDC -> AWS` ;
- moins de cout et moins d'operations hors sujet ;
- separation plus claire entre CI SaaS et composants plateforme auto-heberges ;
- meilleure reutilisation du role `gitlab-runner` entre lab local et runner
  bootstrap prive.

Negatives :

- dependance a `GitLab.com` pour la CI ;
- certaines validations `S0-T9` ne peuvent pas se reduire a un simple "job
  local" et devront etre prouvees via enregistrement du runner et job de smoke
  test sur GitLab.

## Impacts de mise en oeuvre

Pour `S0-T9` :

- le role `gitlab-runner` doit separer installation et enregistrement ;
- le Docker executor reste le mode cible ;
- le token d'enregistrement ou d'authentification runner doit etre fourni
  depuis une source externe ;
- la preuve minimale attendue devient : runner configure sans secret versionne,
  service actif, et smoke test GitLab possible une fois le token fourni.

## Risques acceptes

- le projet depend d'un service SaaS externe pour sa CI ;
- une adaptation future peut etre necessaire si GitLab change encore son modele
  de tokens runner.
