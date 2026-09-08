# Preuve S1-T5 - ApplicationSet staging

Date : 2026-09-08

## Perimetre

Cette preuve couvre `S1-T5` : remplacer les `Application` Argo CD declarees une par une par un `ApplicationSet` qui les genere, et separer le socle d'un environnement de ce qui tourne dedans.

## Ce qui change

Avant, une seule `Application` `staging` empaquetait tout : le namespace, les policies et l'integralite du workload. Ajouter un service aurait impose d'editer cet assemblage, puis, a mesure que les services se multiplient, de declarer des `Application` a la main.

Desormais, un generateur `git` scanne `gitops/apps/*/overlays/staging` et cree une `Application` par application trouvee. **Ajouter un service revient a creer un repertoire.**

```text
gitops/apps/smoke/overlays/staging   ->  Application "staging-smoke"
gitops/apps/<futur>/overlays/staging ->  Application "staging-<futur>"
```

Le nom est derive du chemin : `segments` vaut `[gitops, apps, <nom>, overlays, staging]`, donc l'index 2 porte le nom de l'application.

## Separation du socle et des applications

L'`Application` `staging` est reduite au socle de l'environnement. La repartition est verifiable directement dans Argo CD :

| Application | Ressources possedees |
|---|---|
| `staging` | `Namespace/shopdemo-staging`, `NetworkPolicy/default-deny-ingress`, `NetworkPolicy/allow-ingress-same-namespace` |
| `staging-smoke` | `ServiceAccount/smoke`, `Deployment/smoke`, `Service/smoke`, `PodDisruptionBudget/smoke` |

Aucun recouvrement, donc aucun conflit de propriete. La frontiere est nette : ce qui **definit** l'environnement d'un cote, ce qui **tourne dedans** de l'autre.

## Le transfert de propriete s'est fait sans interruption

Point qui meritait verification : le passage d'une `Application` a l'autre n'a pas detruit le workload. Le `Deployment` a conserve son age, il n'a jamais ete recree.

Argo CD identifie le proprietaire d'une ressource par une annotation :

```bash
kubectl get deployment smoke -n shopdemo-staging \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'
# staging-smoke:apps/Deployment:shopdemo-staging/smoke
```

Des que `staging-smoke` a synchronise, l'annotation a change de proprietaire, et l'`Application` `staging` a cesse de considerer ces objets comme les siens. Elle ne les a donc jamais elaguees, malgre son `prune: true`.

## Validation

```bash
yamllint gitops
kubectl kustomize gitops/environments/staging | kubeconform -strict -ignore-missing-schemas -summary
kubectl apply --dry-run=server -f gitops/argocd/applicationset-staging.yaml
```

Etat obtenu, sans qu'aucune `Application` applicative n'ait ete ecrite a la main :

```text
NAME            PATH                                 SYNC     HEALTH
platform        gitops/platform                      Synced   Healthy
prod            gitops/environments/prod             Synced   Healthy
staging         gitops/environments/staging          Synced   Healthy
staging-smoke   gitops/apps/smoke/overlays/staging   Synced   Healthy
```

## L'ApplicationSet possede le cycle de vie

Une suppression manuelle de l'`Application` generee a ete tentee. Elle a ete **recreee en moins de dix secondes**, ce qui confirme qu'on ne gere pas a la main une `Application` generee : la source de verite est le contenu du depot, pas l'objet dans le cluster.

## Decouverte importante : la suppression est destructive par defaut

Cette suppression manuelle a aussi detruit puis recree le workload, ce qui n'etait pas anticipe. La cause est le comportement par defaut de l'`ApplicationSet` :

```bash
kubectl get applicationset staging-apps -n argocd -o jsonpath='{.spec.syncPolicy}'
# vide, donc preserveResourcesOnDeletion vaut false
```

Quand une `Application` generee disparait, ses ressources sont supprimees avec elle.

C'est le comportement voulu pour une mise hors service : retirer le repertoire d'un service dans Git doit bien retirer le service du cluster. Mais la consequence merite d'etre connue, car elle transforme une erreur benigne en suppression reelle. Un chemin de generateur mal ecrit, une faute de frappe lors d'une reorganisation de repertoires, et **toutes les applications qui ne correspondent plus au motif sont supprimees**, workloads compris.

Sur staging, dans un lab, le cout est nul : le workload est revenu en une minute. Sur prod, ce serait une panne. C'est un point a trancher explicitement en `S1-T6`, ou `preserveResourcesOnDeletion: true` constituerait un filet de securite au prix d'un nettoyage manuel lors des vraies mises hors service.

## Ce que cette preuve ne couvre pas

Aucune sync wave n'est utilisee. L'ordre entre le socle et les applications n'est pas garanti : une `Application` applicative peut tenter de se deployer avant que son namespace existe. En pratique le namespace preexiste et Argo CD reessaie, mais l'ordre reste implicite.

L'`ApplicationSet` ne couvre que staging. Prod garde son `Application` manuelle, en attendant le modele par tags de `S1-T6`.

Un seul repertoire correspond aujourd'hui au motif du generateur, donc la generation multiple n'a pas encore ete eprouvee sur plusieurs applications reelles.
