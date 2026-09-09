# ADR-008 - NetworkPolicy standard par defaut, CiliumNetworkPolicy par exception

## Statut

Accepte le 2026-09-07, pendant `S1-T3`.

## Contexte

Le projet utilise `Cilium` comme CNI : en replacement mode sur le `k3s` local ([`ADR-004`](ADR-004-use-k3s-cilium-replacement-mode.md)), et en chaining mode sur la cible EKS decrite dans [`ARCHITECTURE.md`](../../ARCHITECTURE.md). Deux API de politique reseau sont donc disponibles simultanement dans le cluster, et `S1-T3` est le premier lot qui en ecrit reellement.

La premiere est `NetworkPolicy`, l'API standard `networking.k8s.io/v1` de Kubernetes. Elle raisonne en namespaces, en selecteurs de pods et en CIDR. Elle fonctionne sur n'importe quel CNI qui l'implemente, donc le meme manifest reste valable si la couche reseau change.

La seconde est `CiliumNetworkPolicy`, specifique a Cilium. Elle ajoute des capacites que l'API standard ne sait pas exprimer, notamment `toFQDNs` pour autoriser un egress vers un nom de domaine, et des regles de niveau applicatif L7.

Le besoin concret qui force la question est le suivant. Argo CD doit joindre `gitlab.com` pour lire le depot GitOps. Or `gitlab.com` est servi derriere Cloudflare : ses adresses IP changent. Avec une `NetworkPolicy` standard, cet egress ne peut s'exprimer qu'en CIDR, donc soit avec une liste fragile qui cassera au prochain changement d'IP, soit avec une plage tellement large qu'elle ne protege plus rien. C'est exactement le cas d'usage de `toFQDNs`.

## Decision

`NetworkPolicy` standard est l'API par defaut du projet pour toute l'isolation generique intra-cluster : isolation par namespace, autorisations entre pods, futurs flux gateway vers services applicatifs.

`CiliumNetworkPolicy` est reservee aux cas que l'API standard ne sait pas exprimer, et chaque usage doit etre justifie dans la documentation du lot concerne. Les deux cas anticipes aujourd'hui sont l'egress par nom de domaine, typiquement `argocd` vers `gitlab.com` puis plus tard vers des endpoints AWS, et d'eventuelles regles L7 si un besoin apparait.

Perimetre reel a la date de cet ADR : `S1-T3` n'utilise que l'API standard, et aucune `CiliumNetworkPolicy` n'existe encore dans le depot.

## Ce que CiliumNetworkPolicy permet en plus

Cette section documente l'ecart de capacite entre les deux API, pour que le choix reste comprehensible sans avoir a l'experimenter.

Niveau de preuve, a lire avant de reutiliser ces exemples :

| Element | Etat | Comment |
|---|---|---|
| Existence des champs cites | Verifie | `kubectl explain cnp.spec` sur la CRD `cilium.io/v2` livree par Cilium `v1.19.5`, Kubernetes `v1.33.1+k3s1` |
| Validite des deux ressources completes | Verifie | `kubectl apply --dry-run=server`, acceptees par l'API serveur sans creation |
| Comportement reseau reel | **Non verifie** | Aucune `CiliumNetworkPolicy` n'a jamais ete appliquee dans ce depot |

Un manifest accepte par le serveur est syntaxiquement correct et conforme au schema. Cela ne dit rien de son effet sur le trafic, qui devra etre mesure avant/apres le jour ou une de ces policies sera reellement posee.

### Le refus par defaut devient explicite

Avec l'API standard, un pod devient isole en entree parce qu'une policy le selectionne. Le refus est un effet de bord de la selection, jamais une declaration. Cilium ajoute un champ qui le dit :

```yaml
spec:
  enableDefaultDeny:
    ingress: true
    egress: false
```

Sans ce champ, la valeur par defaut vaut `true` pour chaque direction qui porte des regles, et `false` sinon, ce qui reproduit la semantique standard. Le rendre explicite retire l'ambiguite qui fait que l'on croit souvent le refus produit par un objet nomme `default-deny`.

### Le refus devient une regle a part entiere

`ingressDeny` et `egressDeny` sont evalues **avant** les autorisations et les emportent, quelle que soit la policy qui autorise par ailleurs :

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: refuser-default
  namespace: shopdemo-staging
spec:
  endpointSelector: {}
  ingressDeny:
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: default
```

C'est ce que l'API standard ne sait pas faire. Le prix est reel : l'union des `NetworkPolicy` standard est commutative, donc ajouter une policy ne peut qu'ajouter une permission et deux equipes ne peuvent pas se casser mutuellement. Introduire du `deny` retire cette garantie et ramene le raisonnement par preseance des pare-feux classiques.

### Les entites nommees

L'API standard ne sait designer que des pods, des namespaces et des CIDR. Cilium ajoute des entites que le cluster resout lui meme :

`all`, `cluster`, `health`, `host`, `ingress`, `init`, `kube-apiserver`, `none`, `remote-node`, `unmanaged`, `world`

```yaml
  ingress:
    - fromEntities: [cluster]     # tout le cluster, sans lister les namespaces
  egress:
    - toEntities: [world]         # tout ce qui est hors du cluster
```

Exprimer "depuis l'exterieur du cluster" en API standard demanderait une liste de CIDR a maintenir, et `kube-apiserver` n'a tout simplement pas d'equivalent portable.

### L'egress par nom de domaine

C'est le cas d'usage deja anticipe plus bas dans cet ADR, et la vraie raison pour laquelle Cilium sera necessaire :

```yaml
  egress:
    - toFQDNs:
        - matchName: gitlab.com
      toPorts:
        - ports: [{port: "443", protocol: TCP}]
```

L'API standard ne connait que des adresses IP. Autoriser Argo CD vers GitLab y exigerait une liste de CIDR qui casserait silencieusement au prochain changement d'adresses.

### Le niveau applicatif

Cilium sait filtrer sur le contenu HTTP, ce qui sort completement du perimetre de l'API standard :

```yaml
      toPorts:
        - ports: [{port: "8080", protocol: TCP}]
          rules:
            http:
              - method: GET
                path: "/api/catalogue.*"
```

### A quoi ressemblerait notre cas de S1-T3

Par curiosite, l'isolation posee en `S1-T3` s'ecrirait ainsi en une seule ressource :

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: isolation-namespace
  namespace: shopdemo-staging
spec:
  endpointSelector: {}
  ingress:
    - fromEndpoints:
        - {}          # meme namespace : Cilium ajoute la contrainte implicitement
```

Une ressource au lieu de deux, mais le gain est illusoire. On perd la portabilite vers un autre CNI, on perd le filet decouple que constitue une policy de refus dont le cycle de vie est independant, et on introduit une API supplementaire pour un besoin que le standard couvre parfaitement. C'est exactement le raisonnement qui a conduit a la decision de cet ADR.

### Piege de documentation

`fromRequires`, presente dans de nombreux articles comme le moyen d'imposer une contrainte transverse, est marquee `Deprecated` dans la CRD de Cilium `v1.19.5`. Ne pas la reprendre depuis un exemple ancien sans verifier son statut sur la version installee.

## Alternatives considerees

### 1. Tout ecrire en NetworkPolicy standard

Avantage : un seul modele a apprendre et a relire, portable vers n'importe quel CNI.

Inconvenient : l'egress par nom de domaine devient impossible a exprimer proprement. Autoriser Argo CD vers GitLab exigerait une liste de CIDR a maintenir a la main, qui casserait silencieusement le jour ou Cloudflare change d'adresses. Un blocage de ce type couperait Argo CD de sa source, donc de sa capacite a se reparer.

Decision : rejetee comme approche unique.

### 2. Tout ecrire en CiliumNetworkPolicy

Avantage : un seul modele, avec toutes les capacites disponibles partout.

Inconvenient : lie l'integralite du modele reseau a un CNI precis, alors que la majorite de ce modele n'a besoin d'aucune fonctionnalite specifique. Rend aussi les manifests moins lisibles pour quelqu'un qui connait Kubernetes mais pas Cilium, ce qui va contre l'objectif pedagogique et portfolio du projet.

Decision : rejetee.

## Consequences

Positives :

- la majeure partie du modele reseau reste portable et lisible avec des connaissances Kubernetes standard ;
- la partie specifique a Cilium reste petite, identifiee et justifiee cas par cas ;
- le projet peut demontrer les deux API et expliquer pourquoi chacune est utilisee la ou elle l'est, ce qui est un bon sujet d'entretien.

Negatives :

- deux API coexistent, donc un audit de flux doit regarder les deux et non une seule ;
- les semantiques different sur des details : une `CiliumNetworkPolicy` peut etre namespacee ou cluster-wide, ce qui demande de la rigueur dans le nommage et le placement ;
- un lecteur pressé peut croire qu'un flux est autorise en ne regardant qu'une des deux sources.

## Suivi

- `S1-T3` pose l'isolation en entree des namespaces applicatifs en `NetworkPolicy` standard uniquement.
- Le premier usage legitime de `CiliumNetworkPolicy` sera la securisation du namespace `argocd`, avec un egress `toFQDNs` vers `gitlab.com`. Ce lot est volontairement hors perimetre `S1-T3`, parce qu'une erreur y couperait Argo CD de son depot.
- Si le projet finit par n'utiliser qu'une seule des deux API, cet ADR devra etre revu plutot que conserve tel quel.

- Section "Ce que CiliumNetworkPolicy permet en plus" ajoutee le 2026-09-09, apres une question sur la possibilite d'exprimer un refus. Les champs sont verifies contre la CRD installee, le comportement runtime ne l'est pas.

Validation de cet ADR :

```bash
git diff --check
kubectl explain cnp.spec              # champs cites dans la section Cilium
kubectl explain cnp.spec.ingressDeny

# Les deux ressources completes de la section Cilium, validees sans creation
kubectl apply --dry-run=server -f <extrait>
```
