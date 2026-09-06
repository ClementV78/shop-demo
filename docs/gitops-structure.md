# Structure GitOps locale

## Objectif

Ce document decrit la structure GitOps introduite au Sprint 1.

But du lot `S1-T1` :

- poser une arborescence Kubernetes lisible ;
- separer plateforme, applications et environnements ;
- permettre des validations locales sans appliquer sur le cluster ;
- preparer Argo CD sans encore l'installer.

Le chemin durable attendu reste :

```text
Git commit -> Argo CD observe Git -> Argo CD synchronise Kubernetes
```

La CI ne doit pas devenir le mecanisme durable de deploiement Kubernetes. Elle
valide, construit, scanne et met a jour l'etat GitOps ; Argo CD reconcilie
ensuite le cluster.

## Vue d'ensemble

<p align="center">
  <img src="diagrams/s1-gitops-local-overview.svg" alt="Vue d'ensemble GitOps locale Sprint 1" width="1050">
</p>

> Source editable :
> [`diagrams/s1-gitops-local-overview.drawio`](diagrams/s1-gitops-local-overview.drawio).

## Arborescence

```text
gitops/
  README.md
  platform/
    kustomization.yaml
    namespaces/
      base/
        kustomization.yaml
        namespaces.yaml
  apps/
    README.md
  environments/
    README.md
    staging/
      kustomization.yaml
      namespace.yaml
    prod/
      kustomization.yaml
      namespace.yaml
  argocd/
    README.md
```

<p align="center">
  <img src="diagrams/s1-gitops-repo-structure.svg" alt="Structure du repertoire GitOps Sprint 1" width="1050">
</p>

> Source editable :
> [`diagrams/s1-gitops-repo-structure.drawio`](diagrams/s1-gitops-repo-structure.drawio).

## Responsabilites

| Zone | Role | Etat S1-T1 |
|---|---|---|
| `gitops/platform/` | Ressources transverses du cluster | Namespaces `argocd` et `gateway-system` |
| `gitops/apps/` | Bases applicatives reutilisables | Placeholder documente |
| `gitops/environments/staging/` | Assemblage de validation locale/staging | Namespace `shopdemo-staging` |
| `gitops/environments/prod/` | Assemblage production-like | Namespace `shopdemo-prod` |
| `gitops/argocd/` | Objets Argo CD | Placeholder pour `S1-T2+` |

## Namespaces

| Namespace | Responsabilite | Remarque |
|---|---|---|
| `argocd` | Control plane GitOps | Argo CD sera installe plus tard |
| `gateway-system` | Gateway API / NGINX Gateway Fabric / auth gateway | Reserve aux composants plateforme |
| `shopdemo-staging` | Workloads applicatifs de validation | Environnement non production |
| `shopdemo-prod` | Workloads applicatifs production-like | Active plus tard par promotion explicite |

## Convention de promotion

<p align="center">
  <img src="diagrams/s1-gitops-promotion-model.svg" alt="Modele de promotion GitOps Sprint 1" width="1050">
</p>

> Source editable :
> [`diagrams/s1-gitops-promotion-model.drawio`](diagrams/s1-gitops-promotion-model.drawio).

Convention cible, pas encore implementee en `S1-T1` :

- `staging` suit une branche ou un chemin GitOps de validation ;
- `prod` suit une promotion explicite, idealement via tag semver ;
- les images production-like sont referencees par digest immuable ;
- les commits automatiques GitOps utilisent `[skip ci]` pour eviter les boucles
  CI.

## Sync Waves

Convention cible pour les futurs objets Argo CD :

| Wave | Ressources |
|---|---|
| `-10` | Namespaces et pre-requis de base |
| `-5` | CRDs et control planes |
| `-2` | ExternalSecrets et dependances de configuration |
| `0` | Deployments, Services, ServiceAccounts |
| `2` | HTTPRoutes et exposition |

`S1-T1` ne cree pas encore les annotations de sync wave, car les manifests
actuels sont seulement des namespaces et des placeholders.

## Validation locale

Ces commandes rendent les manifests sans rien appliquer :

```bash
kubectl kustomize gitops/platform
kubectl kustomize gitops/environments/staging
kubectl kustomize gitops/environments/prod
```

Validation YAML si `yamllint` est disponible :

```bash
yamllint gitops
```

Validation schema Kubernetes si `kubeconform` est disponible :

```bash
kubectl kustomize gitops/platform | kubeconform -strict -ignore-missing-schemas
kubectl kustomize gitops/environments/staging | kubeconform -strict -ignore-missing-schemas
kubectl kustomize gitops/environments/prod | kubeconform -strict -ignore-missing-schemas
```

## Hors scope de S1-T1

- installer Argo CD ;
- creer les `Application` ou `ApplicationSet` ;
- appliquer les manifests sur le cluster ;
- ajouter les workloads applicatifs ;
- stocker des secrets ;
- connecter Gitea ou GitLab CI au repo GitOps.

Ces sujets commencent a partir de `S1-T2`.

