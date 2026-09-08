# Preuve S1-T4 - Premiere base applicative

Date : 2026-09-08

## Perimetre

Cette preuve couvre `S1-T4` : poser une base applicative reutilisable dans `gitops/apps`, l'assembler pour un environnement, et prouver le chemin complet `base -> overlay -> Application Argo CD -> workload en cours d'execution`.

Aucun service Go n'existe encore dans le depot, donc le workload deploye est volontairement un `smoke`, un serveur HTTP minimal. L'objectif n'est pas l'application metier, mais la structure et les conventions qui accueilleront les vrais services.

## Structure posee

```text
gitops/apps/smoke/
├── base/
│   ├── serviceaccount.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── poddisruptionbudget.yaml
│   └── kustomization.yaml
└── overlays/
    └── staging/
        └── kustomization.yaml
```

L'assemblage se fait dans `gitops/environments/staging/kustomization.yaml`, qui reference l'overlay plutot que de dupliquer les manifests. La base ne sait pas dans quel environnement elle atterrira, l'overlay ne porte que le namespace et le label d'environnement.

Un detail qui merite d'etre explicite : l'overlay ajoute son label avec `includeSelectors: false`. Le selecteur d'un `Deployment` est immuable apres creation, donc y injecter un label rendrait toute mise a jour ulterieure impossible.

## Conventions respectees

| Convention | Mise en oeuvre |
|---|---|
| Image non mutable | Epinglee par digest `sha256:65e3e85d...`, pas par tag |
| ServiceAccount dedie | `smoke`, avec `automountServiceAccountToken: false` puisque le pod n'appelle pas l'API Kubernetes |
| Execution non privilegiee | `runAsNonRoot`, uid 101, `allowPrivilegeEscalation: false`, toutes les capabilities retirees, `seccompProfile: RuntimeDefault` |
| Racine en lecture seule | `readOnlyRootFilesystem: true`, avec des `emptyDir` pour `/tmp` et le cache nginx |
| Ressources bornees | requests 10m / 16Mi, limits 100m / 64Mi |
| Probes | readiness et liveness sur le port HTTP |
| Disponibilite | `PodDisruptionBudget` avec `minAvailable: 1` |

Le choix de deux repliques n'est pas cosmetique. Avec une seule replique, un PDB `minAvailable: 1` interdirait toute eviction volontaire, y compris un drain de noeud pour maintenance, ce qui transformerait une bonne pratique en blocage operationnel.

L'image retenue est `nginx-unprivileged` plutot que `nginx`, parce que la variante standard demarre en root et ecoute sur le port 80, ce qui entre en conflit direct avec `runAsNonRoot`. Choisir une image concue pour ce mode evite de se battre contre elle.

## Validation

```bash
yamllint gitops
kubectl kustomize gitops/environments/staging
kubectl kustomize gitops/environments/staging | kubeconform -strict -ignore-missing-schemas -summary
kubectl kustomize gitops/environments/staging | kubectl apply --dry-run=server -f -
```

Rendu : 7 ressources, toutes valides, dry-run serveur accepte.

## Resultat runtime

La porte de synchronisation manuelle a de nouveau tenu. Apres le push sur GitLab et avant toute action :

```text
staging   OutOfSync
No resources found in shopdemo-staging namespace.
```

Apres declenchement manuel :

```text
staging   Synced / Healthy

pod/smoke-5f47b47656-4rf4k   1/1   Running
pod/smoke-5f47b47656-6jd7x   1/1   Running
deployment.apps/smoke        2/2   2 up-to-date, 2 available
service/smoke                ClusterIP   10.43.84.115   80/TCP
```

## Smoke test

| Test | Resultat | Ce que ca prouve |
|---|---|---|
| `wget http://smoke` depuis `shopdemo-staging` | `<title>Welcome to nginx!</title>` | Le workload sert reellement du HTTP, les probes ne mentent pas |
| `wget http://smoke.shopdemo-staging` depuis `default` | **Bloque** | `default-deny-ingress` s'applique a un vrai workload, pas seulement a un pod de test |
| `id` dans le conteneur | `uid=101(nginx) gid=101(nginx)` | L'execution non-root est effective, pas seulement declaree |
| `securityContext` du pod | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | Le contexte declare est bien celui applique |

Le deuxieme test est le plus interessant : il valide retroactivement les policies posees en `S1-T3`, qui n'avaient ete eprouvees jusque-la que sur un pod de test ephemere cree a la main. Elles s'appliquent bien a un workload gere par GitOps.

## Consequence sur le lint

La limite de largeur de `yamllint` passe de 80 a 160 caracteres dans `.yamllint`. Une reference d'image epinglee par digest depasse 120 caracteres et ne peut pas etre coupee proprement en YAML. La convention d'epinglage prime sur la largeur de ligne, donc c'est la regle de lint qui s'adapte.

## Ce que cette preuve ne couvre pas

Le workload n'est joignable que depuis son propre namespace. Aucune route d'entree n'existe, puisque Gateway API et NGINX Gateway Fabric ne sont pas installes. C'est attendu a ce stade.

Aucun `ApplicationSet` n'est utilise, la synchronisation passe encore par une `Application` par environnement, en mode manuel. C'est le sujet de `S1-T5` et `S1-T6`.

L'overlay `prod` n'existe pas encore. `gitops/environments/prod` ne contient toujours que son namespace et ses policies, sans workload, ce qui est coherent avec un modele de promotion explicite.

Enfin, `smoke` est un substitut. Quand les services Go existeront, ils suivront cette structure, et `smoke` restera utile comme test de bout en bout du chemin GitOps.
