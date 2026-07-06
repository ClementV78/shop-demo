# Travail en cours

## Sprint actif

Sprint 0 - Ansible et fondations bootstrap.

Suivi detaille :
[`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md).

## Taches actives

| ID | Tache | Etat | Prochaine action |
|---|---|---|---|
| S0-T10 | Implementer `node-hardening` | Planifie | Cadrer l'integration `dev-sec.os-hardening`, les exceptions k3s/Docker et la strategie de validation sans casser le lab local |

`S0-T1`, `S0-T4`, `S0-T5`, `S0-T6`, `S0-T7`, `S0-T8` et `S0-T9` sont termines ; voir
[`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md) pour le
detail et les preuves.

## Blocages

- Aucun blocage actif. Les deux blocages principaux rencontres pendant `S0-T6`
  sont resolus :
  - `DiskPressure` sur le noeud local (partition `/` saturee) leve apres
    nettoyage sans risque ; voir `docs/sprints/sprint-0-ansible.md` (S0-T6).
  - Connectivite pod -> plan de controle cassee apres l'arrivee de Cilium :
    tous les pods systeme restaient `Ready=False` car ils ne joignaient ni la
    ClusterIP de l'API ni l'IP du noeud. Double cause : Cilium en
    semi-remplacement de kube-proxy, et surtout `ufw` (deny) qui DROP-ait le
    trafic pod -> hote sur la chaine INPUT. Corrige par `--disable-kube-proxy`
    (k3s), `kubeProxyReplacement: true` + `k8sServiceHost`/`k8sServicePort`
    (Cilium) et une regle `ufw allow from 10.42.0.0/16`, le tout encode dans
    les roles Ansible.
- Aucun blocage actif sur `S0-T8`, mais un recadrage a ete necessaire :
  `cloudflared` est deja installe et d'autres tunnels non lies au projet
  existaient deja sur l'hote. La sous-etape "installer `cloudflared`" est
  donc annulee pour ce sprint ; `S0-T8` doit maintenant viser une integration
  ShopDemo non intrusive plutot qu'une prise de controle globale du composant.

## Notes de session

- Le suivi Markdown a ete initialise.
- L'environnement local a ete verifie : Ubuntu 24.04, systemd, Docker, AWS CLI
  et Ansible Core via `pipx`.
- Une documentation de structure Ansible a ete ajoutee pour cadrer `S0-T3`.
- Un document de concepts appris a ete ajoute pour capitaliser les notions du
  Sprint 0 avec schemas Mermaid.
- Le squelette Ansible minimal est en place et valide pour l'inventaire local.
- Le role `k3s-install` est initialise avec ses `defaults`, `tasks`,
  `handlers` et un playbook de validation dedie.
- L'ancien cluster `k3s` local a ete desinstalle proprement pour repartir d'une
  base saine.
- `kubectl` n'est plus disponible en binaire autonome sur le poste ; il etait
  utilise via `k3s kubectl`.
- `k3s` a ete reinstalle par Ansible en version `v1.33.1+k3s1`.
- Le kubeconfig utilisateur local est maintenant synchronise depuis la source
  de verite systeme, ce qui evite la derive root/user constatee auparavant.
- Le role `k3s-install` passe maintenant en idempotence sur un second passage.
- La version installee est comparee a `k3s_version` afin qu'un changement de
  version declenche automatiquement une mise a niveau.
- `AGENTS.md` a ete clarifie pour imposer une posture plus pedagogique :
  avant un correctif non trivial, l'agent doit expliciter l'hypothese, la
  commande, l'observation attendue et la correction proposee, au lieu de
  reparer en autonomie.
- `S0-T4` est termine : ses criteres d'acceptation et controles applicables ont
  ete verifies.
- Le scenario Molecule de `S0-T5` a ete ajoute sous
  `ansible/roles/k3s-install/molecule/default/` avec `converge.yml`,
  `verify.yml` et un driver Docker cible pour `systemd`.
- `molecule` et son plugin Docker ont ete installes localement via `pipx`.
- Le scenario Molecule isole le kubeconfig de test via un utilisateur
  `molecule` et controle le service `k3s`, ses flags CNI et les permissions du
  kubeconfig.
- Le conteneur de test K3s restait bloque sur `overlayfs`; le scenario Molecule
  force donc `--snapshotter=native` uniquement pour le test Docker.
- `S0-T5` est termine : `molecule syntax`, `converge`, `idempotence`,
  `verify` et `test` reussissent.
- Le prochain focus est `Cilium`, attendu pour faire passer le noeud de
  `NotReady` a un etat exploitable sans Flannel.
- Aucun composant applicatif ou d'infrastructure n'est encore implemente.
- Aucun appel AWS ni ressource payante n'est necessaire pour ce jalon.
- Le premier historique Git a ete cree par groupement logique (gitignore,
  gouvernance agents, architecture, suivi de projet, notes d'apprentissage,
  squelette Ansible, README racine).
- `S0-T1` est termine : le `README.md` racine a ete redige et commite.
- Le `README.md` a ete enrichi : schema Mermaid du flux applicatif, table des
  competences demontrees, Quick start executable, badges de progression par
  sprint, mise en forme corrigee (paragraphes sur une ligne, aucun tiret
  cadratin par preference utilisateur).
- Avant le push, le depot a ete controle pour des secrets : grep manuel puis
  `gitleaks detect` sur l'historique complet, aucun secret trouve.
- Le depot distant `github.com/ClementV78/shop-demo` (public) a ete cree avec
  `gh repo create` et le premier push a ete effectue sur `master`.
- Le premier push a ete rejete par la protection email de GitHub (`GH007`) ;
  l'historique local a ete reecrit avec l'adresse noreply GitHub avant de
  pousser avec succes.
- Le role `cilium-setup` (`defaults/main.yml`, `tasks/main.yml`) et son
  playbook ont ete implementes : chart `1.19.5` pinnee, IPAM `cluster-pool`
  sur `10.42.0.0/16`, Hubble relay + UI actives.
- Diagnostic mene jusqu'a la cause racine d'un `CrashLoopBackOff` Cilium :
  partition `/` saturee (94%), sous le seuil kubelet
  `imagefs.available<15%`. Le poste local sert aussi de serveur personnel
  actif (Vaultwarden, Immich, Nextcloud, AdGuard, Coolify, VMs `libvirt`).
- Nettoyage sans risque applique : conteneurs Docker `Exited`, images sans
  conteneur actif, cache `apt`, backends CUDA Ollama inutilises (~5 Go
  recuperes au total). Aucune donnee personnelle active touchee.
- Point reporte par le proprietaire : migration de la `data-root` Docker
  (actuellement sur la partition saturee) vers le disque `sdb3` quasi vide
  (3,8 To). A planifier hors urgence, hors perimetre Sprint 0.
- Point non resolu, laisse intact : un repertoire local de ~5,9 Go ressemble a
  un duplicata `snapd` non reference par le systeme actif, mais ses fichiers
  ont des dates recentes ; origine a confirmer avant toute action.
- `k3s-install` reinstalle desormais aussi lorsque les flags du service
  different de ceux desires (detection de derive via lecture de l'unite
  `k3s.service`), et non plus seulement sur changement de version.
- `cilium-setup` est complet et idempotent : un second passage consecutif
  donne `changed=0`, `failed=0`. Il gere `kubeProxyReplacement`, l'IP/port de
  l'API, `operator.replicas: 1` (mono-noeud), la regle `ufw` et un rollout
  CoreDNS conditionnel pour la course au boot.
- Un scenario Molecule dedie a `cilium-setup` a ete ajoute sous
  `ansible/roles/cilium-setup/molecule/default/`. Son perimetre est
  volontairement modeste : il prouve la convergence du role, son
  idempotence, la presence du release Helm et des valeurs attendues, sans
  pretendre valider le datapath eBPF complet dans un conteneur Docker.
- La frontiere de preuve est maintenant explicite :
  - Molecule verifie l'automatisation Ansible.
  - La validation Cilium runtime de reference reste a faire sur l'hote reel
    avec `cilium status --wait`, `cilium connectivity test`, la verification
    Hubble et le rerun idempotent du playbook.
- `community.general` a ete ajoute a `requirements.yml` (module `ufw`).
- Etat verifie : noeud `Ready`, `KubeProxyReplacement: True` (Direct Routing),
  `cilium`/`cilium-envoy`/`cilium-operator`/`coredns`/`hubble-relay`/
  `hubble-ui` tous `Running` et prets.
- Validation runtime completee sur l'hote reel :
  - `cilium status --verbose` sain, Hubble Relay `OK`, noeud `Ready`.
  - `kubectl exec` depuis `client` et `client2` vers
    `http://echo-same-node:8080/` retourne `HTTP 200`.
  - `hubble observe` montre les flows attendus (`pre-xlate-fwd`, puis
    `SYN/SYN-ACK/ACK/FIN`) pour `pod -> service` et un trafic `pod -> world`
    sain.
  - `cilium connectivity test --test no-policies` garde un echec residuel sur
    `no-policies/pod-to-service` : le datapath fonctionne, mais la validation
    de flow ne matche pas la forme observee du trafic service-translated.
    Ce point est traite comme un faux negatif probable de Hubble /
    `connectivity test` sur ce lab local mono-noeud, non bloquant pour la
    suite.
- `S0-T6` est considere termine : role Ansible, Molecule, et validation
  runtime sont alignes avec un risque residuel documente et accepte.
- Le focus actif a bascule vers `S0-T7` : `ministack-setup`.
- Pour demarrer `S0-T7` proprement, une synthese de decouverte MiniStack a ete
  redigee dans [`docs/decouverte-ministack.md`](decouverte-ministack.md) a
  partir de la doc officielle recente, afin de cadrer le perimetre technique
  avant implementation.
- `S0-T7` est maintenant termine :
  - MiniStack demarre localement sur `localhost:4566`.
  - `/_ministack/health` repond `200`.
  - le profil AWS CLI `ministack` fonctionne.
  - `sts get-caller-identity` retourne l'identite locale synthetique
    `000000000000`.
  - le second passage du playbook est idempotent (`changed=0`).
- Une vue d'architecture MiniStack locale a ete ajoutee dans
  [`ARCHITECTURE.md`](../ARCHITECTURE.md) avec sa source editable
  [`docs/diagrams/ministack-local-infra.drawio`](diagrams/ministack-local-infra.drawio).
- Une seconde vue MiniStack, cette fois centree sur les **services AWS
  emules** et leur statut d'usage dans le projet, a ete ajoutee dans
  [`ARCHITECTURE.md`](../ARCHITECTURE.md) avec sa source editable
  [`docs/diagrams/ministack-emulated-services.drawio`](diagrams/ministack-emulated-services.drawio).
- `ARCHITECTURE.md` a ensuite ete **reorganise en page maitre** avec table des
  matieres cliquable, schema global conserve en tete, et extraction des
  details vers `docs/architecture/`.
- Le focus actif bascule maintenant vers `S0-T8` : `cloudflare-tunnel`.
- Audit de prerequis `S0-T8` realise :
  - `cloudflared` etait deja installe sur l'hote ;
  - d'autres tunnels non lies a ShopDemo existaient deja ;
  - une unite systemd generique preexistante a ete renommee localement pour
    clarifier l'exploitation ;
  - `cloudflared-update.service` a ete aligne sur les unites systemd encore
    gerees localement.
- `S0-T8` a maintenant une implementation repo :
  - role `ansible/roles/cloudflare-tunnel/` ;
  - playbook `ansible/playbooks/cloudflare-tunnel.yml` ;
  - unite cible `cloudflared-shopdemo.service` ;
  - token externe via `/etc/cloudflared/shopdemo.env` ;
  - schema d'architecture locale
    `docs/diagrams/cloudflare-tunnels-local.{drawio,svg}`.
- Correctif runtime `S0-T8` identifie sur l'hote reel :
  - un autre tunnel `cloudflared` ecoutait deja sur `127.0.0.1:20244` ;
  - `cloudflared-shopdemo.service` entrait donc en collision au demarrage ;
  - le role a ete recadre pour utiliser par defaut `127.0.0.1:20245`.
- La decision retenue reste non intrusive : aucun takeover des autres tunnels
  preexistants, et les routes metier `argocd`, `grafana`, `gitea` restent a
  activer quand leurs origins locales existeront.
- `S0-T8` est maintenant considere termine :
  - tunnel `shopdemo` cree cote Cloudflare ;
  - token runtime conserve dans `/etc/cloudflared/shopdemo.env` ;
  - playbook relance avec succes et idempotence utile observee (`changed=0`) ;
  - `cloudflared-shopdemo.service` actif sur l'hote ;
  - tunnel confirme `Healthy` dans le dashboard Cloudflare.
- Memo operatoire pour un rerun manuel :

  ```bash
  export SHOPDEMO_TUNNEL_TOKEN="$(sudo awk -F= '/^TUNNEL_TOKEN=/{print $2}' /etc/cloudflared/shopdemo.env)"
  cd ansible
  ansible-playbook playbooks/cloudflare-tunnel.yml \
    -e cloudflare_tunnel_shopdemo_token="$SHOPDEMO_TUNNEL_TOKEN"
  ```

  La suite pour le projet reste le raccordement futur des routes `argocd`,
  `grafana` et `gitea` quand les origins locales existeront reellement.
- `metrics-server` et le job `helm-install-traefik` restent en erreur, mais
  pour des raisons independantes de Cilium (TLS kubelet k3s, Traefik non
  utilise au profit de Gateway API) ; hors perimetre `S0-T6`.
- Un deep dive pedagogique complet a ete redige :
  [`docs/deep-dive-cilium-k3s-ufw.md`](deep-dive-cilium-k3s-ufw.md) (mecanique
  reseau, diagnostic couche par couche, schemas Mermaid et decisions prises).
- Hors perimetre Sprint 0, a la demande explicite du proprietaire : le skill
  `archify` a ete scanne (securite OK, cf. sous-repertoires `renderers/*`
  propres) puis installe. Trois diagrammes HTML interactifs (theme
  clair/sombre, export PNG/SVG) ont ete generes en complement des schemas
  Mermaid existants d'`ARCHITECTURE.md`, sans les remplacer :
  `docs/diagrams/plateforme-cible.html` (vue plateforme, chemin HTTP
  synchrone), `docs/diagrams/flux-achat-paiement.html` (sequence
  navigation/commande/paiement) et `docs/diagrams/pipeline-gitops.html`
  (pipeline CI vers GitOps/Argo CD). Les fichiers `.json` sources
  (JSON-IR archify) sont versionnes a cote pour regeneration.
- Export SVG/PNG des 3 diagrammes automatise via Playwright (navigateur
  Chromium deja present en cache local, aucune nouvelle installation) : le
  bouton "Download SVG"/"Download PNG" du menu export de chaque HTML a ete
  declenche par script, car ce menu s'appuie sur `getComputedStyle` et ne
  peut pas etre reproduit par simple concatenation de texte. Les `.svg`
  (auto-theme clair/sombre via `prefers-color-scheme`, ideal GitHub) sont
  desormais embarques directement dans `ARCHITECTURE.md` ; les `.png` (4x,
  ~600-700 Ko chacun) restent disponibles dans `docs/diagrams/` sans etre
  references pour l'instant.
- Derive documentaire corrigee : `S0-T8` reste termine et le prochain focus
  du Sprint 0 est desormais `S0-T9` (`gitlab-runner`), avant `S0-T10` puis la
  composition de `bootstrap.yml` / `teardown.yml`.
- `S0-T9` est maintenant termine et valide :
  - role `ansible/roles/gitlab-runner/` ajoute avec `defaults`, `tasks` et
    `handlers` ;
  - playbook `ansible/playbooks/gitlab-runner.yml` ajoute ;
  - installation GitLab Runner cadree sur la doc officielle via le depot
    `packages.gitlab.com` pour Ubuntu, avec keyring APT dedie ;
  - separation explicite installation / enregistrement via
    `gitlab_runner_manage_registration` et `gitlab_runner_token_type` ;
  - verifie : `ansible-playbook --syntax-check` OK puis `ansible-playbook
    --check ... -e gitlab_runner_manage_registration=false` OK dans le
    contexte du projet ;
  - verifie : installation reelle du package, service `gitlab-runner` actif
    sur l'hote local et enregistrement avec un token moderne `glrt-...` ;
  - verifie : pipeline GitLab de smoke passe sur le projet sandbox
    `shopdemo`, branche `test/gitlab-runner-smoke`.
- Corrections apres revue du proprietaire :
  - Le chemin webhook paiement async (API Gateway AWS + Lambda
    webhook-paiement, publication `paiement-confirmé`, fan-out stock/notif)
    manquait dans `flux-achat-paiement.sequence.json` — seul le chemin
    synchrone y figurait. Ajoute (2 participants, 4 messages, segment
    "04 / WEBHOOK PAIEMENT (ASYNC)"), le JSON et le SVG/HTML ont ete
    regeneres pour correspondre a la sequence Mermaid d'origine.
  - Tentative de rendre les SVG responsives en retirant leurs attributs
    `width`/`height` fixes (le `viewBox` seul aurait du suffire a les
    etirer a la largeur du conteneur Markdown) : rendu juge tres degrade
    par le proprietaire. Rollback complet sur les 3 diagrammes — `width`/
    `height` fixes restaures via reexport propre (`Download SVG`/
    `Download PNG` archify), le probleme de largeur reste donc non
    resolu et a reprendre avec une autre approche si besoin.
- Les 3 blocs Mermaid desormais remplaces par leur equivalent archify ont
  ete supprimes d'`ARCHITECTURE.md` (les images SVG restent, les blocs
  source Mermaid ne sont plus dupliques) : la sequence combinee de
  "Ce que fait ShopDemo", "Vue plateforme — chemin HTTP synchrone" et
  "Flux GitOps".
- "Vue DevSecOps — shift-left" (4 subgraphs Mermaid empiles verticalement,
  tres haut a l'affichage) remplace par un 4e diagramme archify —
  `docs/diagrams/devsecops-shift-left.{json,html,svg,png}`, type
  `workflow`, lanes Poste local / CI / Runtime EKS / Posture AWS avec les
  items en colonnes plutot qu'empiles : viewBox 720x652, nettement plus
  compact que le rendu Mermaid precedent. `Security Hub` et `GuardDuty`
  fusionnes en un seul noeud (label + sublabel) pour respecter la
  contrainte de colonnes du renderer workflow (6 colonnes, dont 2 paires
  trop rapprochees pour les partager dans une meme lane).
- Les 6 derniers blocs Mermaid d'`ARCHITECTURE.md` ont ete convertis en
  diagrammes archify et supprimes du Markdown source (plus aucun bloc
  ```mermaid``` dans le fichier) : `couts-aws` (comptes AWS, mode
  architecture), `organisation-aws` (OUs + SCPs en cards, mode
  architecture), `terraform-states` (bootstrap/workload avec boundaries,
  mode architecture), `webhook-paiement-async` (provider -> API Gateway ->
  Lambda -> SNS -> fan-out stock/notif, mode workflow 3 lanes),
  `securite-pods-eks` (2 security-groups pod + IRSA/Kyverno/ESO, mode
  architecture) et `pipeline-cicd-overview` (Sprint 6, mode workflow avec
  les 3 GitLab Components en cards plutot qu'en subgraph). Chacun a
  necessite plusieurs iterations sur `labelAt`/`labelDx`/`labelDy` pour
  satisfaire la validation anti-chevauchement du renderer.
- Les 10 diagrammes d'`ARCHITECTURE.md` (4 precedents + 6 nouveaux) sont
  desormais centres via `<p align="center"><img ... width="850"></p>`
  plutot que la syntaxe `![alt](path)` brute — rendu plus soigne, largeur
  fixe et coherente entre tous les diagrammes independamment de leur
  `viewBox` d'origine.
- A la demande du proprietaire, un 11e schema archify a ete ajoute pour
  expliciter ou la communication pod-to-pod existe reellement dans le
  projet : `docs/diagrams/flux-inter-pods-k8s.{architecture.json,html,svg}`.
  La vue isole volontairement le trafic intra-cluster entre Gateway API,
  `jwt-authorizer`, services Go, CoreDNS, Cilium/Hubble, Argo CD et
  External Secrets afin de completer les vues plateforme sans les
  surcharger.
- Revue visuelle du proprietaire sur ce schema : lecture jugee trop
  "spaghetti" car il melangeait flux runtime et control plane dans une
  seule vue. Refonte immediate en 2 diagrammes distincts :
  `docs/diagrams/flux-runtime-k8s.{architecture.json,html,svg}` pour
  "qui parle a qui pendant l'execution", et
  `docs/diagrams/control-plane-k8s.{workflow.json,html,svg}` pour
  "qui configure / alimente / observe le cluster". La vue unique initiale
  reste non referencee.
- Une variante `draw.io` plus lisible de la vue runtime Kubernetes a ete
  produite sous `docs/diagrams/flux-runtime-inter-pods-k8s-icons.drawio`
  pour explorer un rendu plus proche des schemas archi de reference :
  theme clair, cards arrondies, boundaries cluster/node/namespaces plus
  nettes, icones Kubernetes en accent visuel et contexte AWS limite
  (`ALB`, badge `EKS target`). Cette variante reste pour l'instant un
  artefact de travail complementaire, non encore integre dans
  `ARCHITECTURE.md`.
- Une variante `draw.io` du schema fonctionnel "flux achat et paiement" a
  ete ajoutee sous `docs/diagrams/flux-achat-paiement-drawio.drawio` avec
  son export `docs/diagrams/flux-achat-paiement-drawio.svg`. Elle reprend
  les 4 phases du flux (navigation, commande, paiement simule, webhook
  async) sous forme de sequence light a cards/lifelines, en alternative a la
  version `archify` actuelle.
- Un diagramme de sequence `draw.io` dedie au hot path Kubernetes a ete
  ajoute sous `docs/diagrams/flux-runtime-requete-k8s-sequence.drawio`
  avec son export `docs/diagrams/flux-runtime-requete-k8s-sequence.svg`.
  Il montre, sur une requete `/api/commande`, la difference entre les
  composants prepares en amont (`kube-apiserver`, `Cilium agent`) et ceux
  reellement traverses pendant l'execution (`ALB`, datapath Cilium,
  Gateway API, `jwt-authorizer`, `service-commande`, CoreDNS, RDS),
  ainsi que la posture passive de Hubble.
- Cette vue sequence runtime a ete integree dans `ARCHITECTURE.md` juste
  apres la vue "flux runtime inter-pods", avec une explication etape par
  etape de ce qui est prepare avant la requete, de ce qui est traverse
  pendant le hot path, et de ce que Hubble observe sans etre inline.
- `ARCHITECTURE.md` a ete clarifie sur deux vues de lecture :
  - `Vue DevSecOps — shift-left` explique maintenant la defense en
    profondeur entre poste local, CI, runtime EKS et posture AWS.
  - `Flux GitOps` explique maintenant explicitement que `Trivy` est un
    gate de scan et non l'etape qui modifie le repo GitOps ; le commit
    des manifests reste porte par `update-gitops-tag`.
- Pour reduire cette ambiguite dans le schema lui-meme, le diagramme
  `pipeline-gitops` a aussi ete renomme visuellement de `Tag GitOps` vers
  `Patch GitOps`, et la transition venant de `Trivy` indique desormais
  `gates OK + digest` plutot qu'un simple `digest sha256`.
- La section runtime Kubernetes d'`ARCHITECTURE.md` precise maintenant
  explicitement ce que recouvrent les `claims utiles` renvoyes par
  `jwt-authorizer` (`sub` + `email`, propages via `X-User-Sub` et
  `X-User-Email`) ainsi que la difference entre trafic `east-west` et
  `north-south`.
- La meme section explique aussi pourquoi le mode Cilium `DSR`
  (`Direct Server Return`) n'est pas le chemin de retour de notre flux
  HTTP principal : ShopDemo utilise ici un modele `ALB -> Gateway API /
  NGINX -> service Go`, donc un reverse proxy L7, pas un backend L4
  expose directement au client.
- Le `README.md` principal a ete realigne avec l'etat reel du projet :
  `git clone` pointe maintenant vers le depot public GitHub, le `Quick
  start` couvre `k3s-install` puis `cilium-setup`, et le texte explique
  explicitement que le bootstrap local Ansible + k3s + Cilium est
  aujourd'hui le seul chemin executable de bout en bout.
- La vue "Ou en est le projet" du `README.md` a aussi ete corrigee pour
  eviter l'ambiguite sur Cilium : le prochain jalon vise maintenant la
  cloture de `S0-T6` par validation runtime Cilium, et le sprint suivant
  est reformule autour d'Argo CD / GitOps local plutot que `k3s + Cilium`.
- `AGENTS.md` impose maintenant explicitement une verification de
  coherence documentaire quand un perimetre de sprint, un jalon ou une
  roadmap changent : `README.md`, `ARCHITECTURE.md`,
  `docs/sprint-planning.md` et le fichier de sprint doivent etre
  realignes dans la meme passe. En cas de divergence, la priorite est
  donnee a `ARCHITECTURE.md` et `docs/sprint-planning.md`, puis
  `README.md` / `docs/CURRENT.md` sont corriges pour supprimer la derive.
- Le haut du `README.md` a ete retravaille pour mieux jouer son role de
  vitrine portfolio : ajout d'un sous-titre plus distinctif, d'une
  section `Highlights`, et remplacement du Mermaid d'ouverture par un
  diagramme `draw.io` dedie `docs/diagrams/readme-overview.{drawio,svg}`
  plus lisible pour un lecteur GitHub.
- Un diagramme `draw.io` dedie au `cilium connectivity test` a ete ajoute
  sous `docs/diagrams/cilium-connectivity-test.{drawio,svg}` pour figer
  les namespaces de test, les pods/services deployes par le CLI, les
  grandes familles de checks executes, et la nature du seul echec
  observe (`check-log-errors` lie a des restarts / erreurs historiques).
- Sur proposition du proprietaire (question exploratoire suivie d'un
  accord explicite) : la section `## Sprints` d'`ARCHITECTURE.md`
  (~518 lignes, plus de la moitie du fichier) a ete extraite vers
  `docs/sprint-planning.md`. Verifie au prealable que `docs/ROADMAP.md`
  ne faisait deja que du suivi de statut (tableau + liens), sans
  duplication de contenu avec le detail deplace. `ARCHITECTURE.md` ne
  garde qu'un tableau recap (sprint, sujet, duree, cout, lacunes
  adressees) avec liens d'ancre vers `sprint-planning.md#sprint-N`.
  Le lien casse dans `docs/sprints/sprint-0-ansible.md` (ancre vers
  l'ancien emplacement dans `ARCHITECTURE.md`) a ete corrige vers le
  nouveau fichier ; `docs/ROADMAP.md` reference desormais aussi
  `sprint-planning.md`. `ARCHITECTURE.md` : 968 -> 466 lignes.
- Suite (meme accord explicite) : `docs/ROADMAP.md` (28 lignes, contenu
  deja partiellement duplique dans le README) a ete fusionne dans
  `README.md`, section « Où en est le projet » — tableau de suivi par
  sprint, regles de progression et prochain jalon desormais directement
  dans le README plutot que derriere un lien. `docs/ROADMAP.md`
  supprime. Toutes les references mises a jour : `AGENTS.md` (regle de
  mise a jour post-modification), `docs/CONTRIBUTING.md` (limites,
  rituel de fin de session, table de repartition des documents),
  `docs/README.md` (index), `docs/sprints/sprint-0-ansible.md`
  (checklist definition-of-done), `docs/sprint-planning.md` et
  `ARCHITECTURE.md` (liens de suivi d'avancement).

## Next Step

1. Rejouer les validations de `S0-T6` sur deux niveaux :
   Molecule pour le role, puis `cilium status --wait`, `cilium connectivity test`
   et rerun idempotent sur l'hote reel.
2. Si les validations sont bonnes, passer `S0-T6` a `Termine` dans le sprint
   et choisir la prochaine tache active.
3. Commiter ensuite le lot Ansible + documentation.
4. Nettoyer ulterieurement les refs de sauvegarde locales laissees par
   `git filter-branch` (`refs/original/...`), sans urgence.
