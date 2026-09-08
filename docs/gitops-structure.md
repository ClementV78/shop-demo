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

Le schema se lit comme une histoire de deploiement, de gauche a droite.

```text
Git contient l'intention
Kustomize assemble les YAML
Argo CD compare Git avec le cluster
Kubernetes applique l'etat reel
```

Chaque piece a un role distinct. Git contient les fichiers qui disent ce que
l'on veut voir exister dans Kubernetes. Kustomize prend ces fichiers et les
assemble en manifests finaux, ce qui permet aussi de verifier localement ce qui
serait envoye au cluster, sans rien appliquer. Argo CD compare ce resultat a
l'etat reel et le corrige.

La chaine complete fonctionne depuis `S1-T5` : un merge dans `main` est
deploye automatiquement en staging, tandis que `platform` et `prod` restent en
synchronisation manuelle, pour des raisons differentes detaillees dans le
fichier de sprint.

<p align="center">
  <img src="diagrams/s1-gitops-local-overview.svg" alt="Vue d'ensemble GitOps locale Sprint 1" width="1050">
</p>

> Source editable :
> [`diagrams/s1-gitops-local-overview.drawio`](diagrams/s1-gitops-local-overview.drawio).

Au debut du flux, le developpeur ne pousse pas une commande `kubectl apply`.
Il modifie le repertoire [`../gitops/`](../gitops/) et committe ce changement.
C'est important : l'intention devient relisible dans Git avant de toucher au
cluster.

Dans ce repertoire, `platform/` decrit ce qui appartient au cluster lui-meme.
Aujourd'hui, c'est minimal : les namespaces techniques `argocd` et
`gateway-system`. Plus tard, ce sera aussi l'endroit naturel pour Argo CD,
Gateway API, Kyverno, External Secrets Operator ou l'observabilite.

Les dossiers `environments/staging/` et `environments/prod/` racontent une
autre histoire : ils representent ce que l'on veut pour un environnement
applicatif donne. En `S1-T1`, ils ne creent encore que les namespaces
`shopdemo-staging` et `shopdemo-prod`, mais ils preparent l'endroit ou l'on
ajoutera les workloads, les routes, les replicas et les references d'images.

La boite `kubectl kustomize` du schema est une etape de verification. Elle ne
deploie rien. Elle permet juste de poser la question : "si Argo CD ou kubectl
rendait ce dossier maintenant, quel YAML Kubernetes sortirait ?". C'est pour
cela qu'on peut valider `S1-T1` sans modifier le cluster.

La partie Argo CD est volontairement dessinee comme une etape suivante par
rapport a `S1-T1`. Depuis `S1-T2` (termine le 2026-09-07), Argo CD observe
reellement Git, rend les manifests, compare le resultat avec l'etat reel du
cluster `k3s`, et synchronise selon la politique choisie (sync automatise +
self-heal pour l'`Application` `platform`).

### Git, Argo CD et Kustomize : qui fait quoi

La vue globale a retenir est celle-ci : Git garde l'intention, Argo CD verifie
que le cluster respecte cette intention, Kustomize prepare le YAML final, puis
Kubernetes applique l'etat reel.

`GitLab.com` et `GitHub` se placent du cote Git. Leur role est d'heberger un
repository, recevoir des commits, exposer des branches et des tags. Ils ne
creent pas de pods et ne parlent pas directement a l'API Kubernetes.
`GitLab.com` est la source de verite lue par Argo CD ; `GitHub` reste un
miroir public en lecture seule alimente par push mirroring
([`ADR-007`](adr/ADR-007-gitlab-source-of-truth-github-mirror.md)).

Argo CD se place du cote Kubernetes. C'est un control plane qui tourne dans le
cluster. Il lit un repository Git, detecte les ecarts entre Git et Kubernetes,
puis synchronise les manifests si la politique du projet l'autorise.

Kustomize est encore plus specialise : il assemble des fichiers YAML. Argo CD
peut l'utiliser automatiquement, et `kubectl kustomize` peut l'utiliser
localement pour verifier le rendu. Mais Kustomize seul ne surveille rien et ne
deploie rien.

Dans le projet, cela donne :

```text
GitLab.com (source de verite)         -> repository GitOps
GitHub (miroir public, lecture seule) -> vitrine portfolio
Argo CD depuis S1-T2               -> reconciliation Git vers Kubernetes
Kustomize depuis S1-T1             -> rendu local des manifests
Kubernetes                        -> namespaces, workloads et etat reel
```

Git et Argo CD sont donc complementaires, pas redondants. Le MVP garde un repo
Git existant comme source de verite et reserve l'effort d'exploitation a Argo
CD, qui apporte la valeur GitOps principale cote Kubernetes.

### Kustomize en clair

Kustomize n'est ni un orchestrateur, ni un outil qui deploie tout seul.

Son role est plus simple : il **assemble des fichiers YAML Kubernetes**.

Dans ce projet, chaque dossier deployable contient un fichier
`kustomization.yaml`. Ce fichier dit a Kustomize quels autres fichiers inclure.

Exemple :

```yaml
resources:
  - namespace.yaml
```

Quand on lance :

```bash
kubectl kustomize gitops/environments/staging
```

Kustomize lit `gitops/environments/staging/kustomization.yaml`, charge
`namespace.yaml`, puis produit un YAML Kubernetes final. Cette commande ne
modifie pas le cluster : elle affiche seulement ce qui serait applique.

Plus tard, Argo CD fera conceptuellement la meme chose :

```text
1. lire un chemin Git
2. rendre les manifests avec Kustomize
3. comparer avec le cluster
4. appliquer si la politique de sync l'autorise
```

La valeur de Kustomize ici est de garder une structure progressive :

- `platform/` pour ce qui appartient au cluster ;
- `apps/` pour les bases applicatives reutilisables ;
- `environments/` pour ce qui change entre staging et prod.

### Exemple concret : d'ou viennent les namespaces

Quand on dit que `S1-T1` configure seulement des namespaces, il faut lire cela
de facon tres concrete : les fichiers GitOps actuels ne contiennent presque que
des objets Kubernetes `kind: Namespace`.

Le point d'entree plateforme est
[`../gitops/platform/kustomization.yaml`](../gitops/platform/kustomization.yaml) :

```yaml
resources:
  - namespaces/base
```

Ce fichier ne nomme pas directement `argocd` ou `gateway-system`. Il dit a
Kustomize d'inclure le dossier `namespaces/base`. Dans ce dossier,
[`../gitops/platform/namespaces/base/kustomization.yaml`](../gitops/platform/namespaces/base/kustomization.yaml)
pointe vers le fichier qui contient les objets reels :

```yaml
resources:
  - namespaces.yaml
```

Le fichier
[`../gitops/platform/namespaces/base/namespaces.yaml`](../gitops/platform/namespaces/base/namespaces.yaml)
contient alors deux ressources :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    app.kubernetes.io/part-of: shopdemo-platform
    app.kubernetes.io/managed-by: gitops
    shopdemo.io/environment: platform
---
apiVersion: v1
kind: Namespace
metadata:
  name: gateway-system
  labels:
    app.kubernetes.io/part-of: shopdemo-platform
    app.kubernetes.io/managed-by: gitops
    shopdemo.io/environment: platform
```

Kustomize n'a pas une instruction speciale du type "create namespace". Il rend
simplement ces deux objets Kubernetes parce qu'ils sont references dans les
`resources`. La creation reelle arrivera seulement si on applique le rendu :

```bash
kubectl apply -k gitops/platform
```

ou, plus tard, si Argo CD synchronise ce chemin Git.

Le meme mecanisme existe cote environnements. En staging,
[`../gitops/environments/staging/kustomization.yaml`](../gitops/environments/staging/kustomization.yaml)
inclut `namespace.yaml`, et ce fichier declare :

```yaml
metadata:
  name: shopdemo-staging
  labels:
    app.kubernetes.io/part-of: shopdemo
    app.kubernetes.io/managed-by: gitops
    shopdemo.io/environment: staging
```

En prod, le meme modele declare `shopdemo-prod` avec
`shopdemo.io/environment: prod`.

Ces namespaces ont chacun une intention :

- `argocd` recevra le control plane Argo CD ;
- `gateway-system` isolera les composants Gateway API / NGINX Gateway Fabric ;
- `shopdemo-staging` isolera les workloads de validation ;
- `shopdemo-prod` isolera le chemin production-like.

## Arborescence

Le deuxieme schema zoome sur le contenu du repertoire `gitops/`.

L'idee est d'eviter un grand dossier `k8s/` ou tout serait melange. Dans un vrai
projet, ce melange devient vite difficile a relire : on ne sait plus si un YAML
sert a installer la plateforme, deployer une application, configurer staging ou
preparer prod. Ici, chaque zone a donc une responsabilite claire.

`platform/` est le socle commun du cluster. Si une ressource doit exister une
fois par cluster, elle a vocation a vivre la. C'est pour cela que les namespaces
techniques `argocd` et `gateway-system` sont dans cette zone.

`apps/` est encore vide fonctionnellement, mais son role est important : il
accueillera les manifests reutilisables des workloads ShopDemo. Une base
applicative ne doit pas savoir toute seule si elle part en staging ou en prod.
Elle decrit plutot la forme generale d'un service.

`environments/` assemble ensuite ces pieces pour un contexte donne. Staging et
prod pourront reutiliser la meme base applicative, mais changer certains
details : le namespace, le nombre de replicas, l'image exacte, les routes ou les
parametres de securite.

Enfin, `argocd/` contient les objets qui pilotent cette lecture. Depuis
`S1-T2`, Argo CD est installe via un manifest pinne et une premiere
`Application` synchronise `gitops/platform` depuis GitLab.com. Les
`AppProject` et `ApplicationSet` restent planifies pour borner puis etendre le
modele GitOps.

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
    install.yaml
    bootstrap-application-platform.yaml
```

<p align="center">
  <img src="diagrams/s1-gitops-repo-structure.svg" alt="Structure du repertoire GitOps Sprint 1" width="1050">
</p>

> Source editable :
> [`diagrams/s1-gitops-repo-structure.drawio`](diagrams/s1-gitops-repo-structure.drawio).

## Responsabilites

| Zone | Role | Etat courant |
|---|---|---|
| `gitops/platform/` | Ressources transverses du cluster | Namespaces `argocd` et `gateway-system` |
| `gitops/apps/` | Bases applicatives reutilisables | Placeholder documente |
| `gitops/environments/staging/` | Assemblage de validation locale/staging | Namespace `shopdemo-staging` |
| `gitops/environments/prod/` | Assemblage production-like | Namespace `shopdemo-prod` |
| `gitops/argocd/` | Objets Argo CD | Placeholder a `S1-T1`, rempli depuis `S1-T2` (`install.yaml`, `bootstrap-application-platform.yaml`) |

Mise a jour `S1-T2` (2026-09-07) : `gitops/argocd/` n'est plus un placeholder,
Argo CD est installe et l'`Application` `platform` est `Synced` / `Healthy`.

## Namespaces

| Namespace | Responsabilite | Remarque |
|---|---|---|
| `argocd` | Control plane GitOps | Argo CD `v3.5.2` installe et actif depuis `S1-T2` |
| `gateway-system` | Gateway API / NGINX Gateway Fabric / auth gateway | Reserve aux composants plateforme |
| `shopdemo-staging` | Workloads applicatifs de validation | Environnement non production |
| `shopdemo-prod` | Workloads applicatifs production-like | Active plus tard par promotion explicite |

## Convention de promotion

Le troisieme schema raconte ce qui se passera quand il y aura de vrais
workloads applicatifs.

<p align="center">
  <img src="diagrams/s1-gitops-promotion-model.svg" alt="Modele de promotion GitOps Sprint 1" width="1050">
</p>

> Source editable :
> [`diagrams/s1-gitops-promotion-model.drawio`](diagrams/s1-gitops-promotion-model.drawio).

Le point de depart est le code applicatif. Un developpeur merge un changement,
puis la CI lance les tests, les scans et la construction d'image. Si tout passe,
l'image est publiee dans une registry. Mais on ne veut pas deployer "un tag qui
bouge" en production-like. On veut pointer vers un digest immuable, par exemple
`sha256:...`, parce qu'il designe exactement un artefact.

Le premier endroit ou ce digest arrive est staging. La CI mettra a jour le repo
GitOps avec un commit du type "staging utilise maintenant ce digest". Argo CD
staging verra ce changement et synchronisera l'environnement de validation.

La prod ne doit pas suivre staging automatiquement par accident. Le schema met
donc un gate de promotion entre les deux : tag semver, validation manuelle, ou
autre decision explicite. Quand la promotion est acceptee, le chemin prod pointe
a son tour vers le digest approuve, puis Argo CD prod synchronise.

Cette convention n'est pas encore implementee. Elle est documentee maintenant
pour que les prochains fichiers GitOps soient ranges dans le bon modele des le
depart.

## Sync Waves

Convention cible pour les futurs objets Argo CD :

| Wave | Ressources |
|---|---|
| `-10` | Namespaces et pre-requis de base |
| `-5` | CRDs et control planes |
| `-2` | ExternalSecrets et dependances de configuration |
| `0` | Deployments, Services, ServiceAccounts |
| `2` | HTTPRoutes et exposition |

Les manifests actuels ne creent pas encore les annotations de sync wave. Cette
convention devient utile lorsque plusieurs applications et dependances seront
synchronisees par Argo CD.

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

Le manifest upstream `gitops/argocd/install.yaml` est exclu par `.yamllint` :
il est genere par le projet Argo CD et valide par dry-run Kubernetes, pas par
les regles de style du depot.

Validation schema Kubernetes si `kubeconform` est disponible :

```bash
kubectl kustomize gitops/platform | kubeconform -strict -ignore-missing-schemas
kubectl kustomize gitops/environments/staging | kubeconform -strict -ignore-missing-schemas
kubectl kustomize gitops/environments/prod | kubeconform -strict -ignore-missing-schemas
```

## Hors scope courant

- ajouter les workloads applicatifs ;
- creer un `AppProject` dedie pour remplacer le projet Argo CD `default` ;
- creer les `ApplicationSet` staging et prod ;
- stocker des secrets ;
- connecter GitLab CI ou GitHub Actions au repo GitOps.

Ces sujets commencent a partir de `S1-T3` et des taches suivantes.
