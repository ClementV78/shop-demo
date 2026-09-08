# Sprint 1 - Argo CD et base GitOps locale

## Objectif

Mettre en place une base GitOps locale au-dessus du cluster `k3s + Cilium`
livre au Sprint 0, avec Argo CD, des manifests Kubernetes versionnes et une
separation claire entre environnements de test.

Conception cible :
[`docs/sprint-planning.md - Sprint 1`](../sprint-planning.md#sprint-1--argo-cd-et-base-gitops-locale).

## Tableau de bord

| ID | Tache | Etat | Depend de |
|---|---|---|---|
| S1-T1 | Cadrer la structure GitOps locale | Termine | S0 |
| S1-T2 | Installer Argo CD sur le lab local | Termine | S1-T1 |
| S1-T3 | Definir les namespaces et NetworkPolicies de base | Termine | S1-T1 |
| S1-T4 | Creer les manifests applicatifs minimaux | Termine | S1-T1 |
| S1-T5 | Ajouter ApplicationSet staging | Termine | S1-T2, S1-T4 |
| S1-T6 | Ajouter ApplicationSet prod base sur tags | Termine | S1-T5 |
| S1-T7 | Documenter usage, rollback et depannage GitOps | Planifie | S1-T5 |

## Cadrage initial

Sprint demarre le 2026-09-06.

Hypotheses de depart :

- le cluster local `k3s` existe deja et Cilium est operationnel ;
- les routes Cloudflare vers `argocd` et `grafana` restent raccordees
  seulement quand les origins locales existent reellement ;
- les secrets restent hors Git et seront injectes via une source externe ou un
  mecanisme documente pendant le sprint ;
- les manifests doivent rester simples au depart pour valider le flux GitOps
  avant d'ajouter des patterns avances.

## S1-T1 - Cadrer la structure GitOps locale

Etat : `Termine`.

Objectif : creer une base GitOps lisible, validable localement, sans installer
Argo CD ni appliquer de ressource sur le cluster.

Livrables :

- arborescence [`../../gitops/`](../../gitops/) creee ;
- separation `platform/`, `apps/`, `environments/` et `argocd/` ;
- namespaces transverses `argocd` et `gateway-system` dans
  `gitops/platform/` ;
- namespaces applicatifs `shopdemo-staging` et `shopdemo-prod` separes par
  environnement ;
- document de reference [`../gitops-structure.md`](../gitops-structure.md) ;
- document pedagogique [`../concepts-sprint-1.md`](../concepts-sprint-1.md) ;
- document transverse [`../comment-ca-marche.md`](../comment-ca-marche.md), mis
  a jour avec Sprint 0 et `S1-T1` ;
- trois schemas Draw.io ajoutes au catalogue.

Ce qui n'a volontairement pas ete fait :

- pas d'installation Argo CD ;
- pas de `kubectl apply` ;
- pas de `ApplicationSet` ;
- pas de NetworkPolicy ;
- pas de secret ni token GitOps.

Raison : `S1-T1` doit d'abord rendre le modele lisible et validable. Les
objets qui modifient le cluster arrivent a partir de `S1-T2`.

## Preuves

| Controle | Etat | Preuve |
|---|---|---|
| Plan de sprint | Verifie | Fichier de suivi mis a jour |
| Structure GitOps | Verifie | `gitops/` cree avec separation plateforme/app/environnements |
| Render Kustomize plateforme | Verifie | `kubectl kustomize gitops/platform` |
| Render Kustomize staging | Verifie | `kubectl kustomize gitops/environments/staging` |
| Render Kustomize prod | Verifie | `kubectl kustomize gitops/environments/prod` |
| Validation YAML GitOps | Verifie | `yamllint gitops` avec `gitops/argocd/install.yaml` exclu car manifest upstream genere |
| Validation schemas Kubernetes | Verifie | `kubeconform -strict -ignore-missing-schemas` sur les rendus Kustomize |
| Schemas Draw.io | Verifie | `validate.py --score` OK et exports SVG generes |
| Installation Argo CD | Verifie | `v3.5.2` pinne, `gitops/argocd/install.yaml`, 7 pods `Running`, 3 CRD presentes |
| Credential Git prive Argo CD | Verifie | Secret cluster non commite, token GitLab dedie lecture seule `argocd-readonly` (role `Reporter`, scope `read_repository`) |
| Application `platform` | Verifie | `gitops/argocd/bootstrap-application-platform.yaml`, cible `gitops/platform`, `Synced` / `Healthy` |
| Sync GitOps plateforme | Verifie | Reconciliation Argo CD reussie depuis GitLab apres resolution du blocage Cilium, voir [`../evidence/sprint-1/s1-t2-cilium-egress-blocker.md`](../evidence/sprint-1/s1-t2-cilium-egress-blocker.md) |
| Namespaces applicatifs crees par GitOps | Verifie | `shopdemo-staging` et `shopdemo-prod` `Active` apres sync manuelle des Applications `staging` et `prod` |
| Porte de synchronisation manuelle | Verifie | Policies poussees sur GitLab : Applications `OutOfSync` et `kubectl get networkpolicies` vide tant que la sync n'est pas declenchee |
| Isolation ingress inter-namespaces | Verifie | Mesure avant/apres : joignable depuis `default` avant, bloque apres, voir [`../evidence/sprint-1/s1-t3-networkpolicies-validation.md`](../evidence/sprint-1/s1-t3-networkpolicies-validation.md) |
| Trafic intra-namespace preserve | Verifie | `probe-in` joint `web.shopdemo-staging` avant et apres application des policies |
| Non-regression egress et DNS | Verifie | Resolution `gitlab.com` et `https://gitlab.com` OK depuis `shopdemo-staging` apres policies |
| Validation NetworkPolicies | Verifie | `yamllint`, `kubeconform -strict`, `kubectl apply --dry-run=server` sur les rendus des deux environnements |
| Base applicative reutilisable | Verifie | `gitops/apps/smoke/base`, rendu 7 ressources valides, `kubeconform` et dry-run serveur OK |
| Assemblage par environnement | Verifie | `gitops/environments/staging` reference l'overlay sans dupliquer les manifests |
| Conventions de workload | Verifie | Digest, ServiceAccount dedie, non-root uid 101, capabilities retirees, requests/limits, probes, PDB |
| Deploiement effectif | Verifie | `deployment.apps/smoke` 2/2 disponibles, `Synced` / `Healthy` apres sync manuelle |
| Smoke test HTTP | Verifie | Reponse nginx obtenue depuis le namespace, voir [`../evidence/sprint-1/s1-t4-manifests-applicatifs.md`](../evidence/sprint-1/s1-t4-manifests-applicatifs.md) |
| Isolation eprouvee sur un vrai workload | Verifie | Requete depuis `default` bloquee par `default-deny-ingress` |
| Generation par ApplicationSet | Verifie | `staging-smoke` creee automatiquement depuis `gitops/apps/*/overlays/staging`, sans Application ecrite a la main |
| Separation socle / applications | Verifie | `staging` possede namespace et policies, `staging-smoke` possede le workload, aucun recouvrement |
| Transfert de propriete sans coupure | Verifie | Annotation `tracking-id` transferee, `Deployment` jamais recree, voir [`../evidence/sprint-1/s1-t5-applicationset-staging.md`](../evidence/sprint-1/s1-t5-applicationset-staging.md) |
| Cycle de vie possede par l'ApplicationSet | Verifie | Suppression manuelle de l'`Application` generee, recreee en moins de dix secondes |
| Promotion par tag semver | Verifie | `prod-smoke` deploie depuis `targetRevision: v*`, revision resolue identique au commit du tag |
| Frontiere entre environnements | Verifie | Un merge dans `main` laisse prod `Synced` sur l'ancien tag, sans ecart signale |
| Reprise automatique d'un tag | Verifie | Tag pose puis aucune intervention : deploiement effectif a t+150s, voir [`../evidence/sprint-1/s1-t6-promotion-prod-par-tags.md`](../evidence/sprint-1/s1-t6-promotion-prod-par-tags.md) |
| Isolation reseau en prod | Verifie | Requete depuis `default` vers `smoke.shopdemo-prod` bloquee |
| Rollback GitOps | Planifie | A renseigner |

## Decisions et ecarts

- Decision : `platform/` est synchronise separement des environnements
  applicatifs. Cela evite qu'une app staging porte par accident des ressources
  globales du cluster ou des objets prod.
- Decision : `S1-T1` reste sans effet de bord runtime. Les validations sont
  limitees au rendu local et aux schemas.
- Decision : la forge Git self-hosted sort de la cible MVP GitOps via
  `ADR-002`. Le repo GitOps cible est `GitLab.com`, source de verite, avec
  `GitHub` en miroir public (`ADR-007`).
- Ecart accepte : la convention cible parle d'`ApplicationSet`, mais aucun
  `ApplicationSet` n'est encore cree. La premiere synchronisation utilise une
  `Application` minimale ; les `ApplicationSet` restent prevus pour `S1-T5` et
  `S1-T6`.
- Decision (2026-09-08) : les politiques de synchronisation suivent le risque,
  et non l'ordre de creation des `Application`. `platform` passe en manuel,
  `staging` en automatique.

  Le decoupage precedent etait un heritage chronologique. `platform` avait ete
  automatise en `S1-T2` pour demontrer le modele, et la porte manuelle avait
  ete posee en `S1-T3` sur les nouveaux chemins, ceux qu'on creait alors.

  L'analyse le contredit : une `NetworkPolicy` est namespacee, donc celle de
  `shopdemo-staging` ne peut pas couper `argocd-repo-server` de GitLab, et
  Argo CD n'a pas besoin de joindre les pods applicatifs pour evaluer leur
  sante. La porte manuelle protegeait donc contre un risque inexistant sur ce
  chemin, pendant que `platform`, seul chemin capable de rendre Argo CD
  inoperant, etait applique sans controle.

  `prod` reste manuel malgre son profil de risque identique a `staging`, mais
  pour une autre raison : il suit encore `targetRevision: main`. L'automatiser
  maintenant enverrait chaque commit directement en production et supprimerait
  la frontiere entre les deux environnements. Son automatisation viendra en
  `S1-T6`, couplee aux tags semver.

  Verifie apres bascule : une mise a l'echelle manuelle de `smoke` a 1 replique
  a ete annulee par `selfHeal` en moins de quinze secondes.
- Dette acceptee : l'`Application` `platform` utilise encore l'`AppProject`
  Argo CD `default` pour rester dans le perimetre minimal de `S1-T2`. Un
  `AppProject` ShopDemo dedie doit etre ajoute avant d'etendre GitOps aux
  workloads applicatifs.

## S1-T2 - Installer Argo CD sur le lab local

Etat : `Termine`.

Objectif : installer Argo CD sur le lab local, sans exposition publique au
depart, puis valider qu'il lit le repo GitOps GitLab et synchronise un etat
simple deja versionne.

Livrables :

- Argo CD `v3.5.2` installe via manifest officiel pinne dans
  [`../../gitops/argocd/install.yaml`](../../gitops/argocd/install.yaml) ;
- installation appliquee en server-side apply pour accepter la taille des CRD
  Argo CD ;
- credential Git prive cree dans le cluster, avec un token GitLab dedie
  lecture seule (`Reporter`, scope `read_repository`) et non versionne ;
- premiere `Application` `platform` creee dans
  [`../../gitops/argocd/bootstrap-application-platform.yaml`](../../gitops/argocd/bootstrap-application-platform.yaml),
  pointant vers `gitops/platform` sur GitLab `main` ;
- synchronisation Argo CD validee : `platform` est `Synced` / `Healthy`.

Incident resolu :

- une panne egress Cilium preexistante a bloque la comparaison GitLab
  (`ComparisonError`) pendant la validation ;
- un workaround iptables a confirme la cause (`CILIUM_POST_nat` active vide),
  mais n'a pas ete conserve comme etat cible ;
- la reparation durable a ete validee apres redemarrage du noeud local et
  relance du playbook [`../../ansible/playbooks/cilium-setup.yml`](../../ansible/playbooks/cilium-setup.yml) :
  Cilium a reconstruit lui-meme `CILIUM_POST_nat`, l'egress pod vers GitLab
  fonctionne, et Argo CD synchronise depuis GitLab.

## S1-T3 - Definir les namespaces et NetworkPolicies de base

Etat : `Termine`.

Objectif : faire exister les namespaces applicatifs par le chemin GitOps, puis
poser une premiere isolation reseau, sans remettre en cause l'egress repare
pendant `S1-T2`.

Livrables :

- deux `Application` Argo CD en synchronisation manuelle,
  [`../../gitops/argocd/application-staging.yaml`](../../gitops/argocd/application-staging.yaml)
  et [`../../gitops/argocd/application-prod.yaml`](../../gitops/argocd/application-prod.yaml),
  qui prennent en charge `gitops/environments/` jusque-la lu par personne ;
- namespaces `shopdemo-staging` et `shopdemo-prod` reellement crees dans le
  cluster, via GitOps et non par un `kubectl` manuel ;
- deux `NetworkPolicy` standard par environnement : `default-deny-ingress` et
  `allow-ingress-same-namespace` ;
- decision d'API tracee dans
  [`../adr/ADR-008-standard-networkpolicy-by-default.md`](../adr/ADR-008-standard-networkpolicy-by-default.md) ;
- preuve avant/apres dans
  [`../evidence/sprint-1/s1-t3-networkpolicies-validation.md`](../evidence/sprint-1/s1-t3-networkpolicies-validation.md).

Decisions de cadrage :

- synchronisation manuelle plutot qu'automatique pour ce lot. Une regle reseau
  erronee poussee dans un chemin synchronise automatiquement pourrait couper
  Argo CD de GitLab, donc l'empecher de recevoir son propre correctif. La porte
  manuelle rend ce scenario impossible ;
- policies limitees a l'ingress, egress laisse entierement ouvert. Cela evite
  de fragiliser le chemin pod vers GitLab tout juste repare, et suffit a poser
  une isolation entre namespaces ;
- namespace `argocd` volontairement hors perimetre. C'est le seul endroit ou
  une erreur de policy coute cher, et il conserve les sept `NetworkPolicy`
  livrees par le manifest d'installation Argo CD ;
- namespace `gateway-system` hors perimetre aussi, tant que NGINX Gateway
  Fabric n'y est pas installe.

Ce qui n'a volontairement pas ete fait :

- pas de restriction d'egress ;
- pas de `CiliumNetworkPolicy`, donc pas encore d'autorisation par nom de
  domaine ;
- pas de policy sur `argocd` ni `gateway-system` ;
- pas de workload applicatif permanent, ce sujet appartient a `S1-T4`.

Dette assumee : securiser le namespace `argocd` avec un egress `toFQDNs` vers
`gitlab.com`, accompagne d'un `AppProject` dedie et d'une procedure de rollback
manuel connue avant d'y toucher.

## S1-T4 - Creer les manifests applicatifs minimaux

Etat : `Termine`.

Objectif : poser une base applicative reutilisable et prouver le chemin
`base -> overlay -> Application Argo CD -> workload en cours d'execution`.

Livrables :

- base [`../../gitops/apps/smoke/base/`](../../gitops/apps/smoke/base/) avec
  `ServiceAccount`, `Deployment`, `Service` et `PodDisruptionBudget` ;
- overlay [`../../gitops/apps/smoke/overlays/staging/`](../../gitops/apps/smoke/overlays/staging/)
  qui n'ajoute que le namespace et le label d'environnement ;
- assemblage dans `gitops/environments/staging`, par reference et non par
  duplication ;
- preuve detaillee dans
  [`../evidence/sprint-1/s1-t4-manifests-applicatifs.md`](../evidence/sprint-1/s1-t4-manifests-applicatifs.md).

Decisions notables :

- le workload est un substitut. Aucun service Go n'existe encore dans le
  depot, donc `smoke` sert a valider la structure et les conventions qui
  accueilleront les vrais services ;
- deux repliques plutot qu'une, parce qu'un PDB `minAvailable: 1` sur une
  replique unique interdirait toute eviction volontaire, y compris un drain de
  noeud ;
- image `nginx-unprivileged` plutot que `nginx`, la variante standard demarrant
  en root sur le port 80, ce qui entre en conflit direct avec `runAsNonRoot` ;
- limite de largeur `yamllint` portee a 160 caracteres, une reference d'image
  epinglee par digest ne pouvant pas etre coupee proprement en YAML.

Ce qui n'a volontairement pas ete fait :

- pas de route d'entree, Gateway API n'etant pas installe ;
- pas d'`ApplicationSet`, sujet de `S1-T5` et `S1-T6` ;
- pas d'overlay `prod`, coherent avec un modele de promotion explicite ;
- pas de HPA, la charge d'un substitut ne le justifiant pas.

## S1-T5 - Ajouter un ApplicationSet staging

Etat : `Termine`.

Objectif : ne plus declarer les `Application` applicatives a la main, et
separer le socle d'un environnement de ce qui tourne dedans.

Livrables :

- [`../../gitops/argocd/applicationset-staging.yaml`](../../gitops/argocd/applicationset-staging.yaml),
  generateur `git` scannant `gitops/apps/*/overlays/staging` ;
- `Application` `staging` reduite au socle, namespace et policies ;
- [`../adr/ADR-009-promotion-par-chemin-plutot-que-par-branche.md`](../adr/ADR-009-promotion-par-chemin-plutot-que-par-branche.md)
  actant l'ecart avec le plan initial ;
- preuve dans
  [`../evidence/sprint-1/s1-t5-applicationset-staging.md`](../evidence/sprint-1/s1-t5-applicationset-staging.md).

Ecart assume avec `docs/sprint-planning.md` :

Le plan prevoyait un `ApplicationSet` surveillant une **branche** `staging`.
Cette branche n'existe pas, et `ADR-006` puis `ADR-007` ont etabli une
separation par chemin sur `main`. `ADR-009` acte donc la promotion par chemin
pour staging et par tag pour prod, plutot que par branches d'environnement
longue duree. Les branches de feature restent le mode de travail normal.

Point de vigilance identifie :

La suppression d'une `Application` generee **detruit ses ressources**, car
`preserveResourcesOnDeletion` vaut `false` par defaut. C'est voulu pour une
mise hors service, mais cela signifie qu'un motif de generateur mal ecrit
supprimerait les workloads qui n'y correspondent plus. A trancher
explicitement pour prod en `S1-T6`.

## S1-T6 - Promotion vers prod sur tags semver

Etat : `Termine`.

Objectif : donner a prod une source differente de staging, pour que la
promotion soit un acte delibere et non la consequence automatique d'un merge.

Livrables :

- [`../../gitops/apps/smoke/overlays/prod/`](../../gitops/apps/smoke/overlays/prod/),
  overlay prod sans lequel le generateur ne trouverait rien ;
- [`../../gitops/argocd/applicationset-prod.yaml`](../../gitops/argocd/applicationset-prod.yaml),
  dont le template utilise `targetRevision: v*` ;
- preuve dans
  [`../evidence/sprint-1/s1-t6-promotion-prod-par-tags.md`](../evidence/sprint-1/s1-t6-promotion-prod-par-tags.md).

Le mecanisme : Argo CD n'evalue les contraintes semver **que sur les tags**,
jamais sur les branches. Prod ignore donc l'avancee de `main` et ne bouge qu'au
prochain tag.

Subtilite a connaitre : un `ApplicationSet` a deux revisions distinctes. Le
generateur scanne `main` pour **decouvrir** les applications, le template
deploie depuis la contrainte semver. Un service devient candidat des son merge,
mais n'est deploye qu'une fois inclus dans un tag.

Risque accepte : `preserveResourcesOnDeletion` reste a `false` en prod, comme
en staging. Choix de coherence et de simplicite, pris en connaissance de la
recommandation inverse. Une erreur de motif dans le generateur supprimerait
donc des workloads de production. Acceptable parce que cette production est un
environnement de demonstration sur lab local, a rediscuter si elle devenait
reellement exploitee.

Point de vigilance : la reprise d'un tag prend jusqu'a trois minutes, la
decouverte reposant sur l'intervalle de reconciliation. Aucun webhook n'existe
entre GitLab et Argo CD, dont le service est en `ClusterIP`.

## Prochaine etape

`S1-T7` : documenter l'usage, le rollback et le depannage GitOps. Le rollback
est la seule ligne encore `Planifie` dans le tableau de preuves, et le modele
par tags le rend particulierement lisible : revenir a un tag anterieur suffit.
