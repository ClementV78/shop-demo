# Travail en cours

## Sprint actif

Sprint 0 - Ansible et fondations bootstrap : `Termine`.
Sprint 1 - Argo CD et base GitOps locale : `Termine` le 2026-09-08.
Sprint 2 - Landing Zone AWS : `En cours`, cadre le 2026-09-09.

Suivi detaille :
[`docs/sprints/sprint-2-landing-zone.md`](sprints/sprint-2-landing-zone.md),
[`docs/sprints/sprint-1-gitops-local.md`](sprints/sprint-1-gitops-local.md) et
[`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md).

Le backend S3 bootstrap a ete cree et le state migre en S2-T2. S2-T3 est termine : apply execute par le proprietaire (8 ajouts), plan suivant sans changement (code 0), rattachements confirmes dans la console.

## Etat du depot Git (a lire avant toute action git)

Restructuration terminee pendant cette session, hors perimetre `S1-T2` mais
prealable a la connexion Argo CD -> repo GitOps :

- la branche par defaut est desormais `main` partout (local, GitHub, GitLab) ;
  `master` n'existe plus nulle part ;
- `git branch --set-upstream-to=gitlab/main main` est en place : un simple
  `git push` / `git pull` cible GitLab par defaut ;
- `GitLab.com` est la source de verite (code, CI, futur repo lu par Argo CD),
  `GitHub` est un miroir public en lecture seule
  ([`ADR-007`](adr/ADR-007-gitlab-source-of-truth-github-mirror.md)) ;
- le push mirroring natif GitLab -> GitHub est configure et actif (option
  "Mirror only protected branches" activee, donc seule `main` est miroitee) ;
- la branche `main` est protegee cote GitLab (`Allowed to push and merge`:
  Maintainers, force-push desactive) ;
- le token `shopdemo-access-token` (project access token, scopes
  `read_api, create_runner, manage_runner, read_repository, write_repository,
  read_registry, write_registry`) a ete recree avec le role `Maintainer` pour
  pouvoir pousser sur `main` malgre la protection ; l'ancien token en cache
  local a ete revoque et remplace. Attention : ce meme token sert aussi au
  runner GitLab CI (`create_runner`/`manage_runner`), verifier si un futur
  souci CI est lie a ce changement de role ;
- mirroring verifie et fonctionnel : `git ls-remote origin refs/heads/main`
  et `git ls-remote gitlab refs/heads/main` matchent (`4c7b8ba`). Le premier
  essai avait echoue avec `terminal prompts disabled` car les identifiants
  etaient embarques dans l'URL du mirror ; la configuration fiable est
  `Authentication method: Username and Password` avec `Username`/`Password`
  (token) dans des champs separes, pas dans l'URL ;
- piege local specifique a cet environnement : dans ce poste, `GIT_ASKPASS`
  pointe vers le script d'invite VSCode et peut faire bloquer `git push`
  indefiniment sans rien afficher si la popup ne s'ouvre pas. Contournement :
  `GIT_ASKPASS= git push` force le prompt dans le terminal texte.

## Prochaine tache

| ID | Tache | Etat | Prochaine action |
|---|---|---|---|
| S2-T3 | Module `aws-organization` | Termine | Apply : 8 ajouts ; plan suivant : code 0 ; rattachements aux OUs confirmes par le proprietaire |
| S2-T4 | Module `aws-scp` | En cours | Policy MFA corrigee et appliquee ; region et verrouillage S3 verifies, autres preuves differees |
| S2-T5 | Module `aws-sso` | Termine | Apply 19 ajouts, matrice du portail et difference fonctionnelle DevAccess/ReadOnly verifies |
| S2-T6 | Module `aws-baseline` | En cours | Socle permanent deploye ; verifier convergence, livraison CloudTrail et recorders Config |

Commandes a connaitre pour toute action Terraform de ce sprint :

```bash
cd terraform/bootstrap
terraform init -backend-config=backend.hcl   # backend.hcl n'est pas versionne
terraform plan
```

Objectif de reprise :

- le management account est choisi depuis le 2026-09-10, apres inventaire.
  Son identifiant reste hors du depot. Compte eligible, aucune Organization,
  `AdministratorAccess` disponible, `0.00 USD` consommes sur 30 jours ;
- **le compte n'est pas vide** : un POC Bedrock AgentCore et un bootstrap CDK
  de juillet 2026 y dorment en `us-east-1`. Ils ne genent pas, les SCPs ne
  s'appliquant jamais au management account, mais ils fausseront l'attribution
  de cout si le POC redemarre ;
- les trois prerequis sont faits le 2026-09-10 : MFA activee sur l'utilisateur
  administrateur (cle U2F, root deja protege), alias de compte `shopdemo-mgmt`
  cree, et profil AWS CLI `shopdemo-mgmt` ajoute en `eu-west-1`. Toujours
  utiliser ce profil, jamais l'ancien qui reste en `us-east-1` pour le POC ;
- contrepartie du profil ajoute plutot que renomme : la cle d'acces existe en
  double dans `~/.aws/credentials`. Une rotation devra mettre a jour les deux
  sections. Sauvegardes horodatees `~/.aws/*.bak-*` creees avant modification,
  a supprimer une fois la situation stabilisee car elles contiennent la cle ;
- la MFA protege la console, pas la cle d'acces statique admin active depuis
  juillet, qui contourne la MFA par construction. Cette cle est necessaire pour
  amorcer `S2-T2` ; sa desactivation est prevue apres Identity Center en
  `S2-T5` et le role OIDC en `S2-T7` ;
- `S2-T3` est termine. Les comptes et OUs sont des fondations permanentes ; ne pas les detruire en fin de session workload. `S2-T4` commence par la comprehension des SCPs et leur test en sandbox ;
- piege deja rencontre et a ne pas re-decouvrir : **le backend ne lit pas le
  bloc `provider`**. Il resout ses credentials separement, d'ou le `profile`
  dans `backend.hcl`. Le garde-fou `allowed_account_ids` ne protege que le
  provider ;
- deux points ont ete tranches en `S2-T1` et n'ont plus a etre rediscutes :
  region `eu-west-1`, et verrou S3 natif via `use_lockfile = true` puisque la
  version installee est Terraform `1.15.5`. Aucune table DynamoDB ;
- `prevent_destroy` sur le bucket de state fait partie des livrables de
  `S2-T2`, pas d'un durcissement ulterieur ;
- respecter la separation `bootstrap` permanent et `workload` ephemere posee
  par [`ADR-003`](adr/ADR-003-separate-bootstrap-and-workload-states.md). Le
  state `workload` n'est pas ouvert dans ce sprint.

Ce qui reste utilisable tel quel du Sprint 1 :

- la chaine GitOps locale, qui continuera de servir de banc d'essai ;
- le guide d'exploitation [`docs/exploitation-gitops.md`](exploitation-gitops.md) ;
- le modele de promotion par tags, transposable a des environnements AWS.

Points de vigilance propres au Sprint 2 :

- **la creation d'un compte AWS est difficilement reversible**. Une erreur
  d'email ou de nom se ferme depuis la console, avec 90 jours de periode
  suspendue. Le plan de `S2-T3` merite une relecture ligne a ligne ;
- **une SCP peut verrouiller un compte**. Aucune SCP n'est attachee a la
  racine de l'Organization, et chacune est eprouvee dans le compte `sandbox`
  avant d'atteindre une OU utile ;
- **le state local intermediaire ne doit jamais etre commite**. Le
  `.gitignore` est pose en `S2-T1`, avant que le premier state existe ;
- MiniStack ne peut pas valider `Organizations` ni les `SCPs`. Le garde-fou
  est la relecture de plan et le compte `sandbox`, pas l'emulation locale ;
- **le risque du bootstrap n'est pas la rejouabilite mais le remplacement**.
  Rejouer un `apply` inchange ne fait rien, cela se prouve avec
  `terraform plan -detailed-exitcode` qui retourne `0`. En revanche, renommer
  le bucket de state ou changer l'email d'un compte declenche un
  destroy/create. D'ou `prevent_destroy` sur ces ressources et la recherche
  systematique de `-/+` et `# forces replacement` dans les plans ;
- **les credits AWS masquent le cout reel**. `S2-T6` livre donc deux budgets :
  `cout-reel` hors credits, qui porte le signal FinOps, et `cout-facture`
  credits inclus, qui sert de detecteur d'epuisement des credits en sortant
  de zero. Pas de budget par compte avant le Sprint 3.

Taches terminees du Sprint 0 :
`S0-T1`, `S0-T2`, `S0-T3`, `S0-T4`, `S0-T5`, `S0-T6`, `S0-T7`, `S0-T8`,
`S0-T9`, `S0-T10`, `S0-T11`, `S0-T12`, `S0-T13`.

Taches terminees du Sprint 1 :
`S1-T1`, `S1-T2`, `S1-T3`, `S1-T4`, `S1-T5`, `S1-T6`, `S1-T7`. Sprint clos.

## Blocages

Pas de blocage actif.

Incident resolu le 2026-09-07 : egress reseau casse sur tout le cluster
`k3s`, regression Cilium independante d'Argo CD.

Symptome : aucun pod ne peut sortir du cluster (DNS, ping passerelle LAN
`192.168.31.1`, requetes HTTP externes echouent toutes en timeout). Bloquait la
synchronisation de l'`Application` Argo CD `platform` (`ComparisonError:
failed to list refs ... dial tcp: lookup gitlab.com ... server misbehaving`),
mais le probleme est plus large que GitOps : c'est une panne reseau
plateforme.

Cause racine identifiee : le job interne Cilium `iptables-reconciliation-loop`
echoue en boucle (800 000+ tentatives sur 44h) en tentant de supprimer une
regle iptables fantome (`OLD_CILIUM_POST_nat` avec `! -d 99.105.108.105/24`,
un CIDR qui ne correspond a rien de reel, probablement un residu du reset
Cilium du 2026-09-05). La bascule interne de Cilium entre son ancien jeu de
regles (`OLD_CILIUM_*`) et le nouveau (`CILIUM_*`) est restee incomplete :
`POSTROUTING` pointe deja vers la nouvelle chaine `CILIUM_POST_nat`, mais elle
est vide, donc plus aucun masquerade NAT pour le trafic sortant des pods.
L'ancienne chaine contient encore les bonnes regles mais n'est plus
referencee nulle part.

Deja tente, sans succes complet :
- redemarrage du pod agent Cilium (`kubectl delete pod -n kube-system -l
  k8s-app=cilium`) : sans effet, l'etat casse vit dans les regles iptables de
  l'hote, pas dans le pod ;
- recreation manuelle de la regle fantome exacte dans `OLD_CILIUM_POST_nat`
  pour permettre au `DELETE` de Cilium de reussir et le laisser terminer sa
  bascule proprement : la commande d'insertion est passee, mais les tentatives
  de reconciliation suivantes echouent encore avec la meme erreur (probable
  divergence de representation interne iptables/nftables entre la regle
  recreee et celle que Cilium cherche a supprimer).

Resolution :
- la premiere validation a separe le probleme DNS interne du probleme egress :
  `kubernetes.default.svc.cluster.local` etait resolu par CoreDNS, mais
  `gitlab.com`, `http://1.1.1.1` et la passerelle LAN restaient injoignables
  depuis un pod. Le routage/service Kubernetes fonctionnait donc, mais pas la
  sortie pod vers l'exterieur ;
- l'inspection iptables a montre que `POSTROUTING` envoyait bien le trafic
  vers la chaine active `CILIUM_POST_nat`, mais que cette chaine etait vide.
  Les regles MASQUERADE utiles etaient encore dans `OLD_CILIUM_POST_nat`,
  chaine inactive et non referencee ;
- un ajout manuel temporaire de MASQUERADE dans `CILIUM_POST_nat` a servi de
  test de causalite : des que le trafic pod `10.42.0.0/24` etait masque par
  l'IP de l'hote, un pod pouvait de nouveau resoudre et joindre GitLab. Cette
  regle manuelle etait volontairement un workaround de diagnostic, pas une
  configuration cible ;
- la reparation durable choisie a ete de revenir a un etat Cilium propre :
  redemarrage complet du noeud `minipc-devops-1`, puis relance du playbook
  [`ansible/playbooks/cilium-setup.yml`](../ansible/playbooks/cilium-setup.yml).
  Cilium a alors reconstruit lui-meme `CILIUM_POST_nat` avec ses regles
  normales, notamment `cilium masquerade non-cluster` ;
- la verification post-reboot a confirme que la regle temporaire n'etait plus
  presente (`NO_TEMP_RULE`), que `net-test` resolvait `gitlab.com` via
  CoreDNS, que l'acces HTTPS vers GitLab repondait (`HTTPS_OK`), puis qu'un
  refresh hard Argo CD faisait passer l'`Application` `platform` en
  `Synced` / `Healthy`.

Diagnostic complet (boucle hypothese/commande/observation, schema Mermaid) :
[`docs/evidence/sprint-1/s1-t2-cilium-egress-blocker.md`](evidence/sprint-1/s1-t2-cilium-egress-blocker.md).

Points de vigilance non bloquants :
- `cloudflared` et d'autres tunnels preexistaient deja sur l'hote ; le role
  ShopDemo reste volontairement non intrusif.
- Le reset k3s/Cilium du 2026-09-05 a supprime l'ancien etat Kubernetes local ;
  c'est accepte pour le lab, mais a garder en tete si un workload local non
  versionne avait ete cree manuellement.
- Un mini-fix technique reste a reprendre plus tard dans le role
  `gitlab-runner` : aligner proprement `gitlab_runner_name` et
  `gitlab_runner_description`.

## Etat valide a date

- `k3s-install` implemente, idempotent et teste avec Molecule.
- `cilium-setup` implemente, idempotent, avec validation runtime reelle sur
  l'hote local.
- `ministack-setup` implemente et valide localement (`health`, profil AWS CLI,
  `sts get-caller-identity`, idempotence).
- `cloudflare-tunnel` implemente et valide pour le tunnel dedie `shopdemo`.
- `gitlab-runner` implemente et valide :
  - `ansible-playbook --syntax-check playbooks/gitlab-runner.yml` OK ;
  - `ansible-playbook --check ... -e gitlab_runner_manage_registration=false`
    OK ;
  - installation reelle du package et service actif sur l'hote local ;
  - enregistrement GitLab avec token moderne `glrt-...` ;
  - pipeline GitLab de smoke passe sur le projet sandbox `shopdemo`.
- `node-hardening` implemente et valide pour le lab local :
  - role minimaliste volontairement non intrusif ;
  - `unattended-upgrades`, permissions sensibles (`~/.kube`, `~/.aws`) et
    verification `journald` ;
  - compromis local vs cloud documente dans l'architecture securite.
- `bootstrap.yml` valide l'idempotence globale du lab local :
  - premier rerun reel apres correction APT GitHub CLI : `changed=2`,
    uniquement sur les fichiers `node-hardening` attendus ;
  - deuxieme rerun reel : `ok=59`, `changed=0`, `failed=0`, `skipped=43`.
- `S1-T1` est termine :
  - structure GitOps locale creee dans [`gitops/`](../gitops/) ;
  - namespaces plateforme et applicatifs separes ;
  - rendus Kustomize, YAML et schemas Kubernetes valides localement ;
  - trois schemas Draw.io ajoutes pour expliquer vue d'ensemble, structure repo
    et promotion.
- `S1-T2` termine (2026-09-07), apres resolution de la panne reseau Cilium
  (voir "Blocages") :
  - Argo CD `v3.5.2` installe via manifest officiel pinne (pas `stable`
    flottant), verse dans [`gitops/argocd/install.yaml`](../gitops/argocd/install.yaml) ;
  - installation faite en `--server-side` (le CRD `applicationsets.argoproj.io`
    depasse la limite de taille d'annotation du client-side apply) ;
  - 7 pods Argo CD `Running`, 3 CRD presentes (`applications`,
    `applicationsets`, `appprojects`) ;
  - secret de credential Git prive cree directement dans le cluster (jamais
    committe), avec un token GitLab dedie lecture seule (`argocd-readonly`,
    role `Reporter`, scope `read_repository` uniquement) plutot que de
    reutiliser le token CI existant plus privilegie ;
  - premiere `Application` `platform` creee
    ([`gitops/argocd/bootstrap-application-platform.yaml`](../gitops/argocd/bootstrap-application-platform.yaml)),
    ciblant `gitops/platform` sur `https://gitlab.com/ClementV78/shopdemo.git`
    branche `main`, sync automatise + self-heal ;
  - sync finale `Synced` / `Healthy` a la revision GitLab
    `57763f42f5eb4e6333d42bfbe5c6ba392dd0accc` ;
  - validation egress post-reboot : Cilium `OK`, `CILIUM_POST_nat`
    repeuplee par Cilium, `net-test` vers `gitlab.com` OK, aucune regle
    temporaire conservee.
- `S1-T3` termine (2026-09-07) :
  - deux `Application` Argo CD en synchronisation manuelle,
    [`gitops/argocd/application-staging.yaml`](../gitops/argocd/application-staging.yaml)
    et [`gitops/argocd/application-prod.yaml`](../gitops/argocd/application-prod.yaml),
    prennent enfin en charge `gitops/environments/` que personne ne lisait ;
  - namespaces `shopdemo-staging` et `shopdemo-prod` crees par le chemin
    GitOps, pas par un `kubectl` manuel ;
  - deux `NetworkPolicy` standard par environnement, `default-deny-ingress` et
    `allow-ingress-same-namespace` ;
  - porte manuelle verifiee : policies poussees sur GitLab, Applications
    `OutOfSync`, et rien applique tant que la sync n'est pas declenchee ;
  - isolation prouvee par mesure avant/apres : joignable depuis `default`
    avant, bloque apres, trafic intra-namespace et egress intacts ;
  - `ADR-008` acte NetworkPolicy standard par defaut et `CiliumNetworkPolicy`
    par exception ; aucune `CiliumNetworkPolicy` n'existe encore.

- `S1-T4` termine (2026-09-08) :
  - base applicative reutilisable dans
    [`gitops/apps/smoke/base/`](../gitops/apps/smoke/base/), assemblee par
    l'overlay staging et referencee depuis `gitops/environments/staging` ;
  - conventions respectees : image epinglee par digest, `ServiceAccount`
    dedie sans token monte, execution non-root uid 101 avec capabilities
    retirees et racine en lecture seule, requests et limits, probes,
    `PodDisruptionBudget` ;
  - deux repliques volontaires, un PDB `minAvailable: 1` sur une replique
    unique interdirait tout drain de noeud ;
  - `deployment.apps/smoke` 2/2 disponibles apres synchronisation manuelle ;
  - smoke test HTTP concluant depuis le namespace, et requete depuis `default`
    bloquee, ce qui eprouve les policies de `S1-T3` sur un vrai workload ;
  - preuve : [`docs/evidence/sprint-1/s1-t4-manifests-applicatifs.md`](evidence/sprint-1/s1-t4-manifests-applicatifs.md).

- `S1-T5` termine (2026-09-08) :
  - [`gitops/argocd/applicationset-staging.yaml`](../gitops/argocd/applicationset-staging.yaml)
    genere une `Application` par application trouvee dans
    `gitops/apps/*/overlays/staging` : ajouter un service revient a creer un
    repertoire ;
  - l'`Application` `staging` est reduite au socle de l'environnement,
    namespace et policies, sans recouvrement avec les applications ;
  - transfert de propriete sans interruption, verifie par l'annotation
    `argocd.argoproj.io/tracking-id` et l'age inchange du `Deployment` ;
  - suppression manuelle d'une `Application` generee : recreee en moins de dix
    secondes par l'`ApplicationSet` ;
  - [`ADR-009`](adr/ADR-009-promotion-par-chemin-plutot-que-par-branche.md)
    acte la promotion par chemin et par tag, ecartant les branches
    d'environnement prevues au plan initial ;
  - preuve : [`docs/evidence/sprint-1/s1-t5-applicationset-staging.md`](evidence/sprint-1/s1-t5-applicationset-staging.md).

- `S1-T6` termine (2026-09-08) :
  - prod suit `targetRevision: v*`, une contrainte semver qu'Argo CD n'evalue
    que sur les tags, jamais sur les branches ;
  - frontiere prouvee dans les deux sens : un merge dans `main` laisse prod
    `Synced` sur l'ancien tag, et un tag pose est repris automatiquement en
    150 secondes sans aucune intervention ;
  - un premier essai a ete ecarte car un rafraichissement force coincidait avec
    la reprise automatique, rendant le resultat non attribuable ;
  - risque accepte : `preserveResourcesOnDeletion` reste `false` en prod ;
  - preuve : [`docs/evidence/sprint-1/s1-t6-promotion-prod-par-tags.md`](evidence/sprint-1/s1-t6-promotion-prod-par-tags.md).

- `S1-T7` termine (2026-09-08), et Sprint 1 clos :
  - guide d'exploitation [`docs/exploitation-gitops.md`](exploitation-gitops.md),
    construit a partir des pieges reels du sprint ;
  - rollback **execute** et non decrit : release defectueuse promue par tag,
    incident constate, correction par tag superieur sur commit anterieur,
    retour a `Healthy` en 72 secondes ;
  - resultat inattendu : le service a repondu pendant tout l'incident, la
    strategie `maxUnavailable: 0` posee en `S1-T4` ayant transforme une panne
    potentielle en deploiement bloque ;
  - preuve : [`docs/evidence/sprint-1/s1-t7-rollback-execute.md`](evidence/sprint-1/s1-t7-rollback-execute.md).

## Documents de reference immediats

- Architecture cible : [`ARCHITECTURE.md`](../ARCHITECTURE.md)
- Sprint 0 detaille : [`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md)
- Sprint 1 detaille : [`docs/sprints/sprint-1-gitops-local.md`](sprints/sprint-1-gitops-local.md)
- Sprint 2 detaille : [`docs/sprints/sprint-2-landing-zone.md`](sprints/sprint-2-landing-zone.md)
- Comment ca marche techniquement : [`docs/comment-ca-marche.md`](comment-ca-marche.md)
- Recit narratif de `S1-T2` avec schemas : [`docs/evidence/sprint-1/recit-s1-t2.md`](evidence/sprint-1/recit-s1-t2.md)
- Structure GitOps : [`docs/gitops-structure.md`](gitops-structure.md)
- Exploitation, rollback et depannage : [`docs/exploitation-gitops.md`](exploitation-gitops.md)
- Promotion vers la production : [`docs/promotion-par-tags.md`](promotion-par-tags.md)
- Concepts Sprint 1 : [`docs/concepts-sprint-1.md`](concepts-sprint-1.md)
- Decision CI GitLab : [`docs/adr/ADR-001-gitlab-com-for-ci.md`](adr/ADR-001-gitlab-com-for-ci.md)
- Decision retrait forge self-hosted : `ADR-002`
- Decisions structurantes Sprint 0 / S1-T1 :
  [`ADR-003`](adr/ADR-003-separate-bootstrap-and-workload-states.md),
  [`ADR-004`](adr/ADR-004-use-k3s-cilium-replacement-mode.md),
  [`ADR-005`](adr/ADR-005-use-ministack-for-local-aws-validation.md),
  [`ADR-006`](adr/ADR-006-structure-gitops-platform-apps-environments.md)
- Decision de cadrage S1-T2 :
  [`ADR-007`](adr/ADR-007-gitlab-source-of-truth-github-mirror.md)
- Decision de cadrage S1-T3 :
  [`ADR-008`](adr/ADR-008-standard-networkpolicy-by-default.md)
- Delivery / GitOps : [`docs/architecture/05-delivery-gitops.md`](architecture/05-delivery-gitops.md)

## Dernieres actions utiles

- `S2-T1` est termine : [`terraform/`](../terraform/) existe a la racine avec
  `bootstrap/`, `modules/` et `envs/`, les conventions sont documentees dans
  [`terraform/README.md`](../terraform/README.md), et `fmt`, `validate` et
  `tflint` passent. Aucune ressource AWS creee, aucun appel a AWS.
- Passe de coherence documentaire du 2026-09-09 : deux schemas publies etaient
  devenus faux et ont ete corriges puis regeneres, `organisation-aws`
  (`Control Tower` hors scope, compte `sandbox` manquant) et
  `terraform-states` (verrou DynamoDB abandonne). Les arborescences de
  `README.md` et de `docs/architecture/07-repo-learning-path.md` ignoraient
  `terraform/`.
- Nouveau schema [`s2-bootstrap-state-sequence`](diagrams/s2-bootstrap-state-sequence.svg)
  pour l'amorcage du state, le concept le plus contre-intuitif du sprint.
- Les schemas Archify se regenerent desormais en ligne de commande avec
  [`docs/diagrams/export-svg.py`](diagrams/export-svg.py), sans navigateur.
  Commande complete dans [`docs/diagrams/README.md`](diagrams/README.md).
- Dette pedagogique du Sprint 1 soldee : `docs/comment-ca-marche.md`
  s'arretait a `S1-T2`, il couvre maintenant `S1-T3` a `S1-T7` puis `S2-T1`,
  et gagne un sommaire cliquable.
- Reste a faire cote schemas : le diagramme d'intersection SCP et IAM, a
  produire en `S2-T4` quand les SCPs existeront, et `docs/concepts-sprint-2.md`
  a remplir tache par tache plutot qu'a ecrire au futur.
- `tflint 0.64.0` a ete installe dans `~/.local/bin`, avec le ruleset AWS
  `0.46.0` epingle dans `terraform/.tflint.hcl`. La premiere utilisation sur
  une machine neuve demande `tflint --init`.
- Piege a connaitre : `.terraform.lock.hcl` **doit** etre commite malgre son
  prefixe, d'ou la ligne de negation dans le `.gitignore`. Il fige les
  empreintes des providers pour que la CI installe les memes binaires que le
  poste local.
- Deux ecarts de `docs/sprint-planning.md` resolus : le repertoire `platform/`
  suppose a la racine, remplace par `terraform/`, et l'organisation
  multi-depots supposee, `shopdemo-gitops` et `shopdemo-platform`, alors que la
  realite est le mono-depot `gitlab.com/ClementV78/shopdemo` acte par
  [`ADR-007`](adr/ADR-007-gitlab-source-of-truth-github-mirror.md).
- A retenir pour `S2-T7` : la condition de confiance OIDC du planning etait un
  placeholder, `project_path:monorg/idp-platform`. Elle doit valoir
  `project_path:ClementV78/shopdemo`, sinon n'importe quel projet GitLab.com
  peut assumer le role AWS.

- Sprint 2 cadre le 2026-09-09, huit taches, aucune ressource AWS creee.
  Quatre choix ont ete arretes au cadrage : le compte AWS existant devient
  management account, quatre comptes enfants dont un `sandbox` sans ressource,
  le state `bootstrap` et le role OIDC entrent dans ce sprint plutot que dans
  le Sprint 3, et la posture couteuse reste derriere `enable_full_posture`.
- L'EC2 runner `bootstrap` n'est volontairement pas cree au Sprint 2 : il n'a
  d'utilite qu'avec le VPC du Sprint 3 et couterait une instance permanente
  entre temps.
- Ecart corrige dans `docs/sprint-planning.md` : le planning annoncait une
  validation MiniStack des SCPs, que `docs/decouverte-ministack.md` exclut
  explicitement. Le garde-fou devient la relecture de plan et le compte
  `sandbox`.

- Sprint 1 est clos : sept taches livrees, trois ADR actes, et la chaine
  complete `merge -> staging` puis `tag -> prod` fonctionne et a ete eprouvee
  par un incident reel.

- `S1-T6` est termine : la promotion vers prod passe par un tag semver, ce qui
  cree une vraie frontiere entre les environnements. Quatre tags de test ont
  ete poses, `v0.1.0` a `v0.4.0`.
- Aucun webhook n'existe entre GitLab et Argo CD, donc une promotion met
  jusqu'a trois minutes a etre vue. Sans consequence en lab, a corriger si
  Argo CD devient joignable de l'exterieur.

- `S1-T5` est termine : les `Application` applicatives sont desormais generees,
  plus declarees. Attention, la suppression d'une `Application` generee detruit
  ses ressources par defaut, ce qui est voulu pour une mise hors service mais
  transforme une erreur de motif en suppression reelle.
- Les politiques de synchronisation ont ete alignees sur le risque le
  2026-09-08 : `platform` en manuel, `staging` en automatique, `prod` en manuel
  jusqu'a ses tags.

- `S1-T4` est termine : une base applicative complete est deployee par le
  chemin GitOps, avec les conventions de securite et de disponibilite
  attendues. Le workload est un substitut, `smoke`, en attendant les services
  Go.
- Quatre skills ont ete ajoutes a la table de routage d'`AGENTS.md` :
  `git-forge-engineer`, `k8s-network-troubleshooter`, `doc-coherence-reviewer`
  et `common-rules`, pour trois domaines qui n'avaient aucun proprietaire.

- `S1-T3` est termine : les namespaces applicatifs existent enfin dans le
  cluster, avec une isolation en entree et une porte de synchronisation
  manuelle qui protege Argo CD d'un auto-verrouillage. Le namespace `argocd`
  reste volontairement hors perimetre, c'est une dette tracee.

- Session du 2026-09-07 (suite) : Argo CD installe et premiere `Application`
  `platform` synchronisee depuis GitLab. La panne d'egress Cilium qui bloquait
  la comparaison GitOps a ete resolue par redemarrage du noeud puis relance du
  playbook `cilium-setup`; le workaround iptables manuel n'est pas conserve.
- `ADR-007` tranche le point laisse ouvert par `ADR-002` : `GitLab.com`
  devient la source de verite unique pour le code, la CI et le repo GitOps lu
  par Argo CD ; `GitHub` reste un miroir public en lecture seule via le push
  mirroring natif GitLab. Le mirroring est configure et verifie fonctionnel
  (voir "Etat du depot Git" plus haut).
- Documentation pedagogique alignee sur l'etat reel de `S1-T2` :
  [`docs/comment-ca-marche.md`](comment-ca-marche.md) gagne un chapitre
  "S1-T2 - Comment Argo CD est installe et synchronise" (manifest pinne,
  piege du client-side apply sur le CRD `applicationsets`, label requis sur
  le secret de credential Git, pont vers l'incident Cilium) ;
  [`docs/concepts-sprint-1.md`](concepts-sprint-1.md),
  [`docs/gitops-structure.md`](gitops-structure.md) et
  [`docs/architecture/05-delivery-gitops.md`](architecture/05-delivery-gitops.md)
  ne decrivent plus Argo CD au futur ; le schema
  `diagrams/comment-ca-marche-s0-s1.drawio` reflete `S1-T2` comme termine.
- Le retrait de la forge Git self-hosted a ete propage aux documents courants,
  aux schemas sources/exports, au role `cloudflare-tunnel`, aux consignes
  agents et aux playbooks Ansible : l'ancien playbook de forge a ete supprime.
- Quatre ADR courts ont ete ajoutes pour acter les decisions structurantes
  deja prises pendant Sprint 0 et `S1-T1` : separation Terraform
  `bootstrap/workload`, k3s local avec Cilium en replacement mode, MiniStack
  comme validation AWS locale limitee, et structure GitOps
  `platform/apps/environments`.
- `ADR-002` acte le retrait de la forge Git self-hosted de la cible MVP
  GitOps. Le chemin cible devient `GitLab.com` ou `GitHub` -> repo GitOps ->
  Argo CD -> Kubernetes.
- [`docs/comment-ca-marche.md`](comment-ca-marche.md) et
  [`docs/gitops-structure.md`](gitops-structure.md) clarifient maintenant la
  difference entre Git, Argo CD, Kustomize et Kubernetes, ainsi que le chemin
  exact par lequel les fichiers `kustomization.yaml` rendent les namespaces
  `argocd`, `gateway-system`, `shopdemo-staging` et `shopdemo-prod`.
- `S1-T1` a demarre Sprint 1 avec une base GitOps sans effet de bord runtime :
  `gitops/platform`, `gitops/apps`, `gitops/environments` et `gitops/argocd`
  existent, les namespaces declaratifs sont separes, et la documentation
  explique le modele avant l'installation Argo CD.
- Ajout de [`docs/comment-ca-marche.md`](comment-ca-marche.md), document vivant
  pour expliquer techniquement comment les sprints sont construits dans le
  code, avec Sprint 0 et `S1-T1` couverts.
- `S0-T12` est termine : les playbooks futurs `runner-setup.yml` et
  `rds-setup.yml` existent avec `*_apply=false` par defaut, assertions
  d'inputs, secrets externes et aucune action AWS/RDS par defaut.
- `S0-T13` a traite le probleme local k3s/Cilium : l'ancien etat k3s
  referencait encore `192.168.31.200` dans les master leases. Le cluster local
  a ete reconstruit via Ansible, puis Cilium a ete rendu explicite sur
  l'interface `br0` via `devices`.
- Verifie apres correction : `ansible-playbook playbooks/k3s-install.yml`
  passe avec `changed=0`, `ansible-playbook playbooks/cilium-setup.yml` passe
  avec `changed=0`, le noeud `minipc-devops-1` est `Ready` sur
  `192.168.31.106`, et tous les pods systeme sont `Running` ou `Completed`.
- `S0-T13` a repris apres liberation d'espace disque : `molecule test` passe
  completement pour `cilium-setup`, `ministack-setup` et `cloudflare-tunnel`.
  `ministack-setup` valide maintenant healthcheck `200`, smoke STS `rc=0` et
  idempotence `changed=0` dans Molecule.
- Verifie pour `S0-T12` : `syntax-check` OK sur les deux playbooks,
  `--check` OK sans appel externe, `ansible-lint` OK en profil `production`,
  `yamllint` OK sur le perimetre touche, et schema Draw.io exporte en SVG.
- La vue d'ensemble Ansible de
  [`docs/ansible-structure.md`](ansible-structure.md) utilise maintenant le
  schema Draw.io comme version principale. Le flux interne du role
  `k3s-install` conserve le schema Mermaid et ajoute une version Draw.io
  comparative, completee par un tableau de lecture detaille.
- Ajout d'un cours accelere Ansible dans
  [`docs/cours-accelere-ansible.md`](cours-accelere-ansible.md), centre sur
  les exemples reels du Sprint 0 : inventaire, playbooks, roles, variables,
  idempotence, handlers, Molecule et frontiere Terraform/Ansible.
- Cadrage documentaire ajoute pour l'evolution agentique : le chemin produit
  cible est `prompt` / `agentic`, `scenario_inline` reste reserve aux tests,
  `scenario_id` est limite aux fixtures dev/local, et `live` est retire de la
  cible. Aucun code applicatif agentique ni schema API correspondant n'existe
  encore dans ce depot.
- Ajout de deux portes d'entree pedagogiques :
  [`docs/comprendre-le-projet.md`](comprendre-le-projet.md) pour la vision
  globale, avec trois schemas Draw.io integres, et
  [`docs/glossaire.md`](glossaire.md) pour les definitions courtes.
- [`docs/concepts-sprint-0.md`](concepts-sprint-0.md) a ete complete et
  restructure autour des apprentissages Sprint 0, avec trois schemas Draw.io
  dedies : execution Ansible, contrat d'un role, et cycle k3s/Cilium.
- `S0-T13` est termine : le rerun reel complet de `bootstrap.yml` passe et le
  deuxieme passage prouve l'idempotence globale avec `changed=0`.
- `S0-T9` a ete valide bout en bout : installation reelle du package
  `gitlab-runner`, service actif sur l'hote local, enregistrement avec token
  moderne `glrt-...`, puis pipeline GitLab de smoke `Passed` sur la branche
  `test/gitlab-runner-smoke`.
- Le role `gitlab-runner` a ete ajuste au workflow GitLab actuel :
  avec un token moderne `--token`, il ne faut pas pousser des options
  reservees cote serveur comme `--tag-list`. Si un futur rerun casse a
  l'enregistrement, verifier d'abord ce point.
- `S0-T10` est clos avec un hardening local minimal, assume comme compromis de
  lab pour ne pas fragiliser `k3s`, Docker et l'acces d'administration ; le
  hardening fort reste reporte aux futures cibles cloud.
- `S0-T11` est clos avec des playbooks `bootstrap.yml`, `harden.yml` et
  `teardown.yml` verifies en `--syntax-check` et `--check`, avec un teardown
  volontairement conservateur limite par defaut a `cloudflared-shopdemo`.
- La branche GitHub `test/gitlab-runner-smoke` a ete mergee dans l'ancienne
  branche par defaut `master` via la PR `#1`. Cette branche a depuis ete
  renommee `main` (voir "Etat du depot Git" ci-dessus) ; en reprise de
  session, repartir de `main` a jour, source de verite `GitLab.com`.
- Restructuration Git de la session du 2026-09-07 : renommage complet
  `master` -> `main` (local, GitHub, GitLab), bascule de `GitLab.com` en
  source de verite du repo GitOps (`ADR-007`), mise en place et validation du
  push mirroring GitLab -> GitHub, et rotation du token `shopdemo-access-token`
  vers le role `Maintainer` pour permettre les push sur `main` protegee.

## Prochaine reprise recommandee

1. Confirmer la convergence S2-T6 avec un plan sans changement et `enable_full_posture = false`.
2. Verifier la livraison d'un evenement d'un compte enfant dans le bucket central et l'etat des quatre recorders AWS Config.
3. Reprendre plus tard les [preuves du lot SCP](../terraform/modules/aws-scp/README.md#preuves-attendues-et-limites-de-test). Root et CloudTrail restent non verifies sans scenario artificiel trompeur.
4. Reprendre les dettes du Sprint 1 quand elles bloqueront : `AppProject`
   dedie, securisation du namespace `argocd`, webhook GitLab vers Argo CD.

## Rappel de maintenance

- `docs/CURRENT.md` doit rester court et oriente reprise de session.
- L'historique detaille, les preuves et les notes longues vivent dans le
  fichier de sprint, les ADR et les documents techniques dedies.
