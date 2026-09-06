# GitOps

Ce repertoire contient l'etat Kubernetes desire qui sera synchronise par
Argo CD pendant le Sprint 1.

Objectif du Sprint 1 :

- demarrer en local sur le cluster `k3s + Cilium` livre au Sprint 0 ;
- garder une structure compatible avec la cible EKS ;
- separer clairement la plateforme, les applications et les environnements ;
- valider les manifests avant toute synchronisation Argo CD.

## Structure

```text
gitops/
  platform/
    namespaces/
      base/
  apps/
  environments/
    staging/
    prod/
```

## Regles

- `platform/` contient les briques transverses : namespaces, Argo CD,
  Gateway API, policies, observabilite ou secrets operators.
- `apps/` contient les workloads applicatifs reutilisables entre
  environnements.
- `environments/` assemble ce qui doit etre applique pour un environnement.
- Un environnement ne doit pas porter les ressources globales du cluster :
  `platform/` est synchronise separement.
- Les secrets reels ne sont jamais stockes ici.
- Les images de production-like devront utiliser des digests immuables.
- La CI ne doit pas appliquer directement les manifests comme chemin durable :
  elle met a jour Git, puis Argo CD synchronise.

## Etat actuel

`S1-T1` pose uniquement le cadrage et les namespaces de base.

- `platform/` cree les namespaces techniques `argocd` et `gateway-system`.
- `environments/staging/` cree le namespace applicatif `shopdemo-staging`.
- `environments/prod/` cree le namespace applicatif `shopdemo-prod`.
- Argo CD n'est pas encore installe par ces manifests.
