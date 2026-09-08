# Preuve S1-T7 - Rollback execute en production

Date : 2026-09-08

## Perimetre

Cette preuve couvre la derniere ligne restee `Planifie` du tableau de preuves du Sprint 1 : le rollback. Le cadrage exigeait de l'**executer reellement**, pas de le decrire.

L'exercice a donc consiste a provoquer une mauvaise release en production, a constater l'incident, puis a le corriger par la procedure documentee.

## Provoquer l'incident

Une release volontairement defectueuse a ete promue : le digest de l'image a ete remplace par une valeur inexistante, ce qui rend l'image impossible a telecharger.

```yaml
images:
  - name: nginxinc/nginx-unprivileged
    digest: sha256:0000000000000000000000000000000000000000000000000000000000000000
```

Promue par un tag, comme n'importe quelle autre mise en production :

```bash
git tag -a v0.5.0 -m "Release defectueuse (exercice de rollback)"
git push gitlab v0.5.0     # 21:33:33
```

## Ce qui s'est passe

```text
21:34:14  commit=2ad4d53c  sante=Healthy      dispo=2/2
21:34:45  commit=2ad4d53c  sante=Healthy      dispo=2/2
21:35:15  commit=4729104f  sante=Progressing  dispo=2/3
```

Etat des pods pendant l'incident :

```text
smoke-7d97f86458-g5rr7   1/1   Running
smoke-7d97f86458-vdqgh   1/1   Running
smoke-c6479b585-h8vxv    0/1   ImagePullBackOff
```

Cause visible directement dans les events du namespace :

```text
Warning  Failed   pod/smoke-c6479b585-h8vxv   Error: ImagePullBackOff
Normal   BackOff  pod/smoke-c6479b585-h8vxv   Back-off pulling image "...@sha256:00000000..."
```

## Le resultat inattendu, et le plus interessant

**Le service a continue de repondre pendant tout l'incident.**

```bash
kubectl exec probe -n shopdemo-prod -- wget -qO- http://smoke
# <title>Welcome to nginx!</title>
```

Une mauvaise release n'a donc pas provoque une panne, mais un **deploiement bloque**. Les deux anciens pods sont restes en service pendant que le nouveau echouait a demarrer.

La cause est la strategie de mise a jour choisie en `S1-T4` :

```yaml
strategy:
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

`maxUnavailable: 0` interdit a Kubernetes de retirer un pod sain avant qu'un nouveau soit pret. Comme le nouveau n'est jamais devenu pret, aucun ancien n'a ete retire.

Consequence operationnelle : Argo CD affiche `Progressing` et non `Degraded`, et le `Deployment` montre moins de pods a jour que de repliques. C'est le signal a reconnaitre, car rien dans le service rendu ne trahit le probleme.

## Le rollback

La procedure ne supprime pas le tag defaillant. Elle pose un tag **superieur** sur un commit **anterieur**, la contrainte `v*` selectionnant le tag semver le plus eleve.

```bash
git tag -a v0.5.1 -m "Rollback de v0.5.0 : retour a l etat de v0.4.0" v0.4.0^{commit}
git push gitlab v0.5.1     # 21:36:28
```

```text
21:37:09  commit=4729104f  sante=Progressing  dispo=2/3  pods=3
21:37:40  commit=2ad4d53c  sante=Healthy      dispo=2/2  pods=2
```

**Retour a l'etat sain en 72 secondes**, sans aucune intervention au-dela du tag.

## Chronologie complete

| Heure | Evenement |
|---|---|
| 21:33:33 | Tag `v0.5.0` pousse, release defectueuse |
| 21:35:15 | Prod deploie la mauvaise version, `Progressing`, pod en `ImagePullBackOff` |
| 21:35:xx | Verification : le service repond toujours |
| 21:36:28 | Tag `v0.5.1` pousse sur le commit sain de `v0.4.0` |
| 21:37:40 | Prod `Healthy`, 2/2, incident clos |

Duree totale de l'incident : environ quatre minutes, dont **zero seconde d'indisponibilite**.

## Ce que l'exercice valide

La procedure de rollback fonctionne et ne demande qu'une commande, sans acces au cluster ni CLI specifique.

L'historique de deploiement conserve par Argo CD suffit a identifier le dernier etat sain :

```bash
kubectl get application prod-smoke -n argocd \
  -o jsonpath='{range .status.history[*]}{.id}{"  "}{.deployedAt}{"  "}{.revision}{"\n"}{end}'
```

Le choix de `maxUnavailable: 0` fait en `S1-T4`, qui pouvait passer pour une convention appliquee sans reflechir, a une consequence tres concrete : il transforme une panne potentielle en deploiement bloque.

## Nettoyage

Le digest invalide a ete retire de `main` apres l'exercice. Prod tourne sur `v0.5.1`, qui pointe sur le commit sain, et `main` retrouve le meme contenu. Aucun nouveau tag n'a ete necessaire, les deux etats etant identiques.

Les tags `v0.5.0` et `v0.5.1` sont conserves : ils documentent qu'un incident a eu lieu et qu'il a ete corrige, ce qu'un tag supprime effacerait.

## Ce que cette preuve ne couvre pas

Le rollback porte sur des manifests. Quand la CI produira des images, il portera sur un digest, mais le mecanisme de tag restera identique.

Aucune alerte n'a signale l'incident. Il a ete constate parce qu'il etait attendu. La detection automatique releve de l'observabilite, hors perimetre du Sprint 1.

Le rollback n'a pas ete teste sur `staging`, qui suit `main` : y revenir en arriere passe par un `git revert`, pas par un tag.
