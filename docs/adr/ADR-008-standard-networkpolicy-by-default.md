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

Validation de cet ADR :

```bash
git diff --check
```
