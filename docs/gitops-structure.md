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

Le schema se lit comme une histoire de deploiement, mais volontairement
incomplete a ce stade du sprint.

```text
Git contient l'intention
Kustomize assemble les YAML
Argo CD comparera Git avec le cluster
Kubernetes applique l'etat reel
```

Pour l'instant, dans `S1-T1`, on pose surtout les deux premieres pieces :
**Git** et **Kustomize**. Git contient les fichiers qui disent ce que l'on veut
voir exister dans Kubernetes. Kustomize sert a prendre ces fichiers et a les
assembler en manifests Kubernetes finaux. On peut donc verifier localement ce
qui serait envoye au cluster, sans encore rien appliquer.

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

La partie Argo CD est volontairement dessinee comme une etape suivante. A partir
de `S1-T2`, Argo CD observera Git, rendra les manifests, comparera le resultat
avec l'etat reel du cluster `k3s`, puis synchronisera si la politique choisie
l'autorise.

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

Enfin, `argocd/` prepare les objets qui piloteront cette lecture : `AppProject`,
`Application` ou `ApplicationSet`. En `S1-T1`, on documente seulement ce futur
emplacement ; on ne donne pas encore le controle du cluster a Argo CD.

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

Cette convention n'est pas encore implementee en `S1-T1`. Elle est documentee
maintenant pour que les prochains fichiers GitOps soient ranges dans le bon
modele des le depart.

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
