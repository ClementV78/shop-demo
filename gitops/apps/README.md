# Application Manifests

Bases applicatives reutilisables, independantes de l'environnement dans lequel
elles seront deployees.

Une base decrit la forme generale d'un service : son `Deployment`, son
`Service`, son `ServiceAccount`, son `PodDisruptionBudget`. Elle ne sait pas
si elle atterrira en staging ou en prod. Ce sont les overlays qui portent ce
qui varie, et l'assemblage final vit dans `gitops/environments/`.

## Contenu actuel

```text
apps/
  smoke/
    base/
      serviceaccount.yaml
      deployment.yaml
      service.yaml
      poddisruptionbudget.yaml
      kustomization.yaml
    overlays/
      staging/
        kustomization.yaml
```

`smoke` est un substitut assume. Aucun service Go n'existe encore dans le
depot, donc ce workload minimal sert a valider la structure, les conventions
et le chemin GitOps complet. Quand les vrais services arriveront, ils suivront
la meme forme, et `smoke` restera utile comme test de bout en bout.

## Conventions attendues sur un workload

- image epinglee par digest, jamais par tag mutable ;
- `ServiceAccount` dedie, sans montage de token si le pod n'appelle pas l'API ;
- execution non-root, capabilities retirees, racine en lecture seule ;
- requests et limits definis ;
- probes de readiness et de liveness ;
- `Service` en `ClusterIP` ;
- `PodDisruptionBudget`, avec au moins deux repliques pour qu'il ne bloque pas
  les evictions volontaires.

Detail a ne pas oublier dans un overlay : ajouter un label avec
`includeSelectors: false`. Le selecteur d'un `Deployment` est immuable apres
creation, l'y injecter rendrait toute mise a jour ulterieure impossible.

## Structure cible

```text
apps/
  smoke/
  shopdemo/
    base/
    overlays/
      staging/
      prod/
```
