# ADR-007 - GitLab.com source de verite GitOps, GitHub en miroir public

## Statut

Accepte.

Precise le point laisse ouvert par
[`ADR-002`](ADR-002-remove-gitea-from-mvp.md) : "choix du repo GitOps a
trancher explicitement : GitLab.com ou GitHub".

## Contexte

Le depot a deux remotes distants :

- `gitlab` : `https://gitlab.com/ClementV78/shopdemo.git` ;
- `origin` : `https://github.com/ClementV78/shop-demo.git`.

`ADR-001` fixe deja `GitLab.com` comme plateforme CI/CD de reference : runner,
OIDC vers AWS, pipelines. `ADR-002` retire Gitea mais laisse ouvert lequel de
GitLab.com ou GitHub sert de source pour Argo CD au moment d'implementer
`S1-T2`.

Faire lire a Argo CD un repo different de celui qui heberge la CI ajouterait
une deuxieme source de verite Git a synchroniser manuellement, avec un risque
de divergence entre l'etat construit par la CI et l'etat applique par Argo CD.

Le projet garde par ailleurs un interet a publier sur GitHub : visibilite
portfolio, lecture facile pour un recruteur ou un entretien, historique de PR
deja utilise (`test/gitlab-runner-smoke` mergee via la PR `#1` sur GitHub).

## Decision

`GitLab.com` devient la source de verite unique pour le code, la CI/CD et le
repo GitOps lu par Argo CD.

`GitHub` devient un miroir public en lecture seule, alimente par le
push mirroring natif de GitLab (Settings > Repository > Mirroring
repositories), avec un token GitHub scope au depot uniquement.

Le chemin GitOps cible devient :

```text
GitLab.com (source de verite) -> repo GitOps -> Argo CD -> Kubernetes
GitLab.com -> push mirroring -> GitHub (miroir public, lecture seule)
```

## Alternatives considerees

### 1. GitHub comme source de verite, GitLab pour la CI uniquement

Avantages : visibilite immediate du code source sur GitHub.

Inconvenients : Argo CD et la CI ne liraient plus le meme depot que celui ou
vivent les pipelines OIDC ; complique le debogage et l'explication du flux en
entretien.

Decision : rejetee.

### 2. Synchronisation manuelle bidirectionnelle

Avantages : aucun outillage supplementaire.

Inconvenients : source de verite ambigue, risque de divergence, non
reproductible.

Decision : rejetee.

### 3. Job CI dedie pour pousser vers GitHub

Avantages : mirroring versionne dans le pipeline.

Inconvenients : ajoute un job, un secret CI (token GitHub) et de la
complexite pour un besoin de simple vitrine en lecture seule.

Decision : rejetee au profit du push mirroring natif GitLab, plus simple pour
ce besoin.

## Consequences

Positives :

- une seule source de verite pour code, CI, OIDC et GitOps ;
- coherent avec `ADR-001` ;
- GitHub reste a jour automatiquement sans job CI supplementaire ;
- portfolio visible publiquement sans dupliquer la logique de build/deploy.

Negatives :

- GitHub devient un miroir en lecture seule : toute contribution ou PR doit
  partir de GitLab, pas de GitHub, pour eviter une divergence ;
- un token GitHub avec droit d'ecriture doit etre cree et stocke cote GitLab
  (hors depot, dans la configuration du projet) ;
- si le mirroring echoue silencieusement, GitHub peut devenir obsolete sans
  alerte automatique. Accepte comme risque de lab : verification manuelle
  ponctuelle suffit, pas d'alerting dedie pour un miroir de vitrine.

## Suivi

- Fait le 2026-09-07 : push mirroring GitLab -> GitHub configure avec
  "Mirror only protected branches", donc seule `main` est miroitee.
- Fait le 2026-09-07 : documentation GitOps mise a jour pour acter
  GitLab.com comme source de verite et GitHub comme miroir public.
- Fait le 2026-09-07 : `S1-T2` configure l'`Application` Argo CD sur
  `https://gitlab.com/ClementV78/shopdemo.git`.

Validation de cet ADR :

```bash
git diff --check
```
