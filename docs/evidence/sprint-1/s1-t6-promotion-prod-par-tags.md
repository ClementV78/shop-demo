# Preuve S1-T6 - Promotion vers prod par tags semver

Date : 2026-09-08

## Perimetre

Cette preuve couvre `S1-T6` : donner a prod une source differente de staging, pour que la promotion devienne un acte delibere plutot qu'une consequence automatique d'un merge.

## Le mecanisme retenu

Argo CD accepte des **contraintes semver** dans `targetRevision`. Point essentiel, confirme par la documentation : ces contraintes ne sont evaluees **que sur les tags**, jamais sur les branches. Avec `v*`, Argo CD retient donc le tag le plus recent qui correspond, et ignore completement l'avancee de `main`.

C'est exactement ce qui separe les deux environnements :

```text
staging  ->  targetRevision: main   ->  suit chaque merge
prod     ->  targetRevision: v*     ->  ne bouge qu'au prochain tag
```

L'`ApplicationSet` prod garde deux notions de revision distinctes, et c'est une subtilite a connaitre. Son **generateur** scanne `main` pour decouvrir quelles applications existent. Son **template** deploie depuis la contrainte semver. Un nouveau service devient donc candidat des son merge, mais ne sera reellement deploye qu'une fois inclus dans un tag.

## La preuve, dans les deux sens

Une frontiere ne se prouve pas en montrant qu'elle laisse passer, ni seulement qu'elle bloque. Il faut les deux.

### Sens 1 : un merge dans `main` n'atteint pas prod

Un changement portant les repliques de 2 a 3 a ete pousse sur `main`, sans tag.

```text
t+25s : prod a 2 repliques
t+50s : prod a 2 repliques
t+75s : prod a 2 repliques

Argo CD : Synced sur 13f9401 (commit du tag v0.1.0)
```

Le detail qui compte est le statut : Argo CD se declare **`Synced`**, pas `OutOfSync`. Du point de vue de prod, il n'y a aucun ecart, puisque sa reference est le tag et non `main`. La frontiere n'est pas une alerte que quelqu'un doit traiter, c'est une absence de lien.

### Sens 2 : un tag est repris automatiquement

Le tag `v0.3.0` a ensuite ete pose, puis **plus rien n'a ete touche**.

```text
18:33:18  tag v0.3.0 pousse
18:33:56  t+30s  : 3 repliques
18:34:26  t+60s  : 3 repliques
18:34:56  t+90s  : 3 repliques
18:35:26  t+120s : 3 repliques
18:35:57  t+150s : 4 repliques  -> reprise automatique
```

Deux minutes trente, ce qui correspond a l'intervalle de reconciliation par defaut de 180 secondes.

### Un premier essai invalide, ecarte

Un test anterieur sur `v0.2.0` avait semble concluant, mais une commande de rafraichissement force avait ete lancee au moment meme ou la reprise automatique se produisait. Impossible d'attribuer le resultat a l'un ou l'autre. Le test a donc ete refait sur un troisieme tag, sans aucune intervention. Un resultat ambigu ne prouve rien, meme quand il va dans le sens attendu.

## Etat final

```text
NAME            REVISION   AUTO                            SYNC     HEALTH
platform        main       <none>                          Synced   Healthy
prod            main       <none>                          Synced   Healthy
prod-smoke      v*         prune + selfHeal                Synced   Healthy
staging         main       prune + selfHeal                Synced   Healthy
staging-smoke   main       prune + selfHeal                Synced   Healthy
```

Les deux `ApplicationSet`, `staging-apps` et `prod-apps`, generent chacun leurs `Application` applicatives. Les deux `Application` `staging` et `prod` ne portent plus que le socle de leur environnement.

L'isolation reseau posee en `S1-T3` a ete verifiee sur le workload de prod : une requete depuis le namespace `default` est bloquee, comme en staging.

## Delai de promotion et absence de webhook

La reprise d'un tag prend jusqu'a trois minutes, parce que la decouverte repose entierement sur l'intervalle de reconciliation. Aucun webhook n'est configure entre GitLab et Argo CD, et le service `argocd-server` est en `ClusterIP`, donc injoignable depuis l'exterieur du cluster.

Pour un lab, attendre trois minutes apres une promotion est sans consequence. Dans un contexte reel, un webhook rendrait le deploiement quasi immediat et supprimerait l'impression que rien ne se passe. C'est un ajout naturel une fois qu'Argo CD sera expose, ce qui dependra du tunnel Cloudflare aujourd'hui hors perimetre.

## Risque accepte : preserveResourcesOnDeletion

La valeur retenue pour prod est `false`, identique a staging. Le comportement est donc le meme : si une `Application` generee disparait, ses ressources sont supprimees.

Cette valeur a ete choisie pour la coherence entre environnements et la simplicite d'explication, en connaissance de la recommandation inverse. Le risque est explicite : une erreur dans le motif du generateur, ou une reorganisation de repertoires, supprimerait les workloads de production qui n'y correspondent plus.

Ce compromis est acceptable ici parce que la "production" du projet est un environnement de demonstration sur un lab local, sans utilisateur ni donnee reelle. Il devrait etre rediscute si cet environnement devenait reellement exploite.

## Ce que cette preuve ne couvre pas

Le generateur prod scanne `main` et non un tag. Une application mergee mais jamais taguee apparaitrait donc comme `Application` cote prod, en essayant de deployer depuis un tag ou son repertoire n'existe pas. Le cas ne s'est pas presente ici, `smoke` etant present dans tous les tags, mais il se produira au premier service ajoute entre deux promotions.

Aucune sync wave n'ordonne le socle et les applications.

La promotion se fait aujourd'hui sur les manifests. Le modele cible de `docs/sprint-planning.md` promeut un **digest d'image**, ce qui suppose une CI qui construit et pousse des images, absente a ce stade.
