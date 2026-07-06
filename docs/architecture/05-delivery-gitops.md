# Delivery And GitOps

[Retour a `ARCHITECTURE.md`](../../ARCHITECTURE.md)

## Flux GitOps

<p align="center"><img src="../diagrams/pipeline-gitops.svg" alt="Pipeline CI/CD vers GitOps" width="850"></p>

> 📊 **Diagramme interactif** : [`../diagrams/pipeline-gitops.html`](../diagrams/pipeline-gitops.html).

Le pipeline separe :

- la **validation** de l'artefact ;
- la **mise a jour GitOps** de l'etat desire ;
- la **synchronisation** du cluster par `Argo CD`.

`Trivy` ne met pas a jour le repo GitOps. Son role est de bloquer ou laisser passer l'artefact. Le commit GitOps est fait par l'etape dediee `update-gitops-tag`, typiquement avec `[skip ci]`.

## Vue GitLab cible

<p align="center"><img src="../diagrams/gitlab-architecture.svg" alt="Architecture GitLab cible du projet" width="980"></p>

> Source editable : [`../diagrams/gitlab-architecture.drawio`](../diagrams/gitlab-architecture.drawio).

Ce schema met l'accent sur les responsabilites :

- `GitLab.com` porte la CI et les shared runners ;
- le role OIDC AWS permet l'authentification sans cle longue duree ;
- le runner bootstrap prive reste reserve aux jobs qui doivent entrer dans le reseau AWS ;
- `Gitea` reste le support du repo GitOps, puis `Argo CD` applique l'etat desire sur le workload.

## Principes de livraison

- builds rootless ;
- digest pinning ;
- SBOM et scans associes ;
- OIDC GitLab vers AWS ;
- separation entre shared runners GitLab.com et runner bootstrap prive.

## Pourquoi GitOps ici

GitOps rend visibles :

- le changement desire ;
- la promotion d'image par digest ;
- le delta reel entre intention et cluster ;
- le role respectif de la CI et du control plane GitOps.
