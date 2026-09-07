# Argo CD

Ce repertoire contient les ressources Argo CD introduites pendant `S1-T2`.

## Etat actuel

- `install.yaml` : manifest officiel Argo CD `v3.5.2` pinne et versionne pour
  rendre l'installation locale reproductible.
- `bootstrap-application-platform.yaml` : premiere `Application` Argo CD,
  pointee vers `gitops/platform` sur GitLab.com, source de verite GitOps.

L'installation reelle se fait en server-side apply, car certains CRD Argo CD
depassent la limite d'annotation du client-side apply.

## Hors scope actuel

- `AppProject` pour borner le perimetre ShopDemo ;
- `ApplicationSet` staging ;
- `ApplicationSet` prod base sur tags ;
- sync waves pour ordonner les ressources.

`S1-T2` utilise encore le projet Argo CD `default` pour rester minimal. Cette
dette est acceptee temporairement : l'`AppProject` dedie doit etre ajoute avant
d'etendre la synchronisation aux workloads applicatifs.
