# ADR-006 - Structurer GitOps en platform, apps et environments

## Statut

Accepte

## Contexte

Le projet doit preparer Argo CD sans melanger les ressources globales du
cluster, les manifests applicatifs reutilisables et les differences entre
staging et prod.

Un dossier Kubernetes unique deviendrait vite ambigu : on ne saurait plus si un
manifeste appartient au socle plateforme, a une application, ou a un
environnement donne.

## Decision

La structure GitOps cible est separee par responsabilite :

```text
gitops/platform/      ressources transverses du cluster
gitops/apps/          bases applicatives reutilisables
gitops/environments/  assemblages staging/prod
gitops/argocd/        objets Argo CD futurs
```

`S1-T1` reste volontairement sans effet de bord runtime : les manifests sont
valides avec `kubectl kustomize`, `yamllint` et `kubeconform`, sans
`kubectl apply`.

## Consequences

Positives :

- separation lisible des responsabilites ;
- promotion staging/prod plus claire ;
- base naturelle pour les futurs `ApplicationSet` Argo CD ;
- validation locale possible avant installation d'Argo CD.

Negatives :

- plus de dossiers au depart ;
- convention a maintenir dans les futurs manifests ;
- besoin de documenter ce que Kustomize rend vraiment.

## Suivi

Les futurs manifests devront respecter cette separation. Les ressources
globales vont dans `platform/`, les bases reutilisables dans `apps/`, et les
choix propres a un environnement dans `environments/`.

Validation documentaire :

```bash
git diff --check
```
