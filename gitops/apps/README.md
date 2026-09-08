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

## Le selecteur est un contrat gele

Un `Deployment` utilise `spec.selector.matchLabels` pour savoir quels pods lui
appartiennent. Kubernetes **interdit de modifier ce champ apres creation**, car
changer le critere de propriete en cours de route laisserait des pods orphelins.

Il faut donc distinguer deux natures de labels.

Un label qui **decrit** (environnement, equipe, version, centre de cout) n'entre
jamais dans le selecteur. Ces labels sont renommes ou reorganises au fil de la
vie du projet, et chacun de ces changements deviendrait impossible.

Un label qui **identifie** l'instance, typiquement `app.kubernetes.io/instance`,
a sa place dans le selecteur, mais a une condition : sa **cle** doit etre
declaree dans la base des la premiere creation, meme si sa valeur est banale.
L'ajouter plus tard est impossible.

Cette declaration anticipee est ce qui rend possible, plus tard, deux instances
de la meme base dans un meme namespace, par exemple une version stable et un
canari. Chaque overlay valorise alors la cle differemment, par un patch cible :

```yaml
# overlays/canari/kustomization.yaml
nameSuffix: -canari
patches:
  - target: {kind: Deployment}
    patch: |
      - op: replace
        path: /spec/selector/matchLabels/app.kubernetes.io~1instance
        value: smoke-canari
```

Les deux `Deployment` ont alors des selecteurs disjoints et ne se disputent
aucun pod. La repartition du trafic entre eux releve de Gateway API, dont les
`HTTPRoute` savent ponderer plusieurs `backendRefs`, et non du selecteur.

Aujourd'hui le besoin n'existe pas : `staging` et `prod` sont separes par
namespace, et un selecteur ne regarde que son propre namespace. La cle
`instance` n'est donc pas encore declaree dans `apps/smoke/base`. Ce serait le
prerequis a poser **avant** tout premier deploiement d'un canari.

## Ajouter un label sans toucher au selecteur

Detail a ne pas oublier dans un overlay qui ajoute un label : utiliser
`includeSelectors: false` **et** `includeTemplates: true`.

Le premier protege le selecteur du `Deployment`, immuable apres creation : y
graver un label rendrait tout renommage ulterieur impossible sans supprimer et
recreer l'objet. Le second garantit que le label atteint quand meme les pods,
sans quoi ils ne seraient filtrables ni pour du debug, ni pour l'attribution
de cout, ni par une `NetworkPolicy` selectionnant par environnement.

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
