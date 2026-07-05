# Sprint 0 - Ansible et fondations bootstrap

## Objectif

Rendre le serveur Ubuntu local reproductible avec Ansible et poser la frontiere
Terraform/Ansible reutilisee pour le runner EC2, RDS et Gitea.

Conception cible :
[`docs/sprint-planning.md - Sprint 0`](../sprint-planning.md#sprint-0--ansible--provisioning-local--fondations-bootstrap).

## Tableau de bord

| ID | Tache | Etat | Depend de |
|---|---|---|---|
| S0-T1 | Initialiser le socle du depot | Termine | - |
| S0-T2 | Verifier l'environnement de travail | Termine | S0-T1 |
| S0-T3 | Creer le squelette Ansible | Termine | S0-T1 |
| S0-T4 | Implementer `k3s-install` | Termine | S0-T2, S0-T3 |
| S0-T5 | Tester `k3s-install` avec Molecule | Termine | S0-T4 |
| S0-T6 | Implementer `cilium-setup` | Termine | S0-T5 |
| S0-T7 | Implementer `ministack-setup` | Termine | S0-T3 |
| S0-T8 | Implementer `cloudflare-tunnel` | Termine | S0-T3 |
| S0-T9 | Implementer `gitlab-runner` | Planifie | S0-T3 |
| S0-T10 | Implementer `node-hardening` | Planifie | S0-T3 |
| S0-T11 | Composer `bootstrap.yml` et `teardown.yml` | Planifie | S0-T6 a S0-T10 |
| S0-T12 | Preparer les playbooks AWS futurs | Planifie | S0-T3 |
| S0-T13 | Valider et documenter le Sprint 0 | Planifie | S0-T5 a S0-T12 |

## S0-E1 - Fondations du projet

### S0-T1 - Initialiser le socle du depot

Etat : `Termine`

- [x] Initialiser le depot Git.
- [x] Ajouter un `README.md` racine.
- [x] Ajouter un `.gitignore` adapte a Ansible, Terraform et aux outils locaux.
- [x] Ajouter le dispositif de suivi Markdown.

#### Criteres d'acceptation

- [x] `git status` fonctionne depuis la racine.
- [x] Les fichiers temporaires, secrets et states Terraform sont ignores.
- [x] Les documents de suivi sont relies entre eux.

#### Notes de progression

- Implemente : premier historique Git cree par groupement logique (gitignore,
  gouvernance agents, architecture, suivi de projet, notes d'apprentissage,
  squelette Ansible, README racine), soit 14 commits.
- Implemente : `README.md` racine avec schema Mermaid du flux applicatif,
  table des competences demontrees, Quick start executable et badges de
  progression par sprint.
- Verifie : aucun secret ni fichier sensible commite, double controle par
  grep manuel des patterns classiques (cles AWS, PEM, tokens) puis par
  `gitleaks detect --source .` sur l'historique complet (13 commits scannes,
  `no leaks found`).
- Cree : depot distant public `github.com/ClementV78/shop-demo` via
  `gh repo create`.
- Corrige : push initial rejete par GitHub (`GH007`, protection anti-fuite
  d'email) car les commits portaient l'adresse email reelle de l'auteur ;
  historique reecrit localement avec l'adresse noreply GitHub
  (`{id}+{login}@users.noreply.github.com`) avant le push reussi.
- Risque accepte : `git filter-branch` laisse des refs de sauvegarde locales
  (`refs/original/...`) ; sans impact sur le remote, nettoyage non urgent.

### S0-T2 - Verifier l'environnement de travail

Etat : `Termine`  
Depend de : `S0-T1`

- [x] Identifier l'OS cible et son mode d'acces.
- [x] Verifier Python, Ansible, Docker, Git et l'AWS CLI.
- [x] Verifier la virtualisation et les contraintes systemd pour Molecule.
- [x] Documenter les versions retenues et les ecarts.

#### Criteres d'acceptation

- [x] Les prerequis disponibles et manquants sont listes.
- [x] La methode d'installation est reproductible.
- [x] Aucun outil global inutile n'est impose.

#### Notes de progression

- Verifie : Ubuntu 24.04.4 LTS, noyau 6.17, `systemd` comme PID 1, aucune
  virtualisation detectee.
- Verifie : `git`, `python3`, `pip3`, `docker`, `aws` et `ansible-core`
  fonctionnent sur le poste.
- Ecart corrige : le paquet `pipx install ansible` n'exposait pas les binaires
  attendus ; `ansible-core` a ete installe via `pipx` a la place.
- Point d'attention : le poste heberge deja plusieurs conteneurs Docker. Cela
  n'empeche pas le Sprint 0, mais impose de surveiller les collisions de ports
  pendant les tests locaux.

### S0-T3 - Creer le squelette Ansible

Etat : `Termine`  
Depend de : `S0-T1`

- [x] Creer `ansible.cfg`.
- [x] Creer `requirements.yml`.
- [x] Creer `inventory/local.yml`.
- [x] Creer `inventory/aws_ec2.yml`.
- [x] Creer `group_vars/all.yml` sans secret.
- [x] Creer les repertoires `roles/`, `playbooks/` et `molecule/`.

#### Criteres d'acceptation

- [x] `ansible-config dump` utilise la configuration du projet.
- [x] `ansible-inventory --graph` affiche l'inventaire local.
- [x] `ansible-galaxy install -r requirements.yml` est reproductible.
- [x] Aucun secret n'est versionne.

#### Notes de progression

- Verifie : l'arborescence [`ansible/`](../../ansible) existe deja avec
  `inventory/`, `group_vars/`, `roles/`, `playbooks/` et `molecule/`.
- Documente : la cible et les relations entre ces elements dans
  [`docs/ansible-structure.md`](../ansible-structure.md).
- Verifie : `ansible-config dump --only-changed` charge bien
  [`ansible/ansible.cfg`](../../ansible/ansible.cfg).
- Corrige : `stdout_callback = yaml` etait incompatible avec l'installation
  locale minimale ; retour a `stdout_callback = default`.
- Verifie : `ansible-inventory --graph` affiche le groupe `local` et l'hote
  `localhost`.
- Verifie : la collection `amazon.aws` est installable depuis
  [`ansible/requirements.yml`](../../ansible/requirements.yml).
- Verifie : le premier role
  [`ansible/roles/k3s-install/`](../../ansible/roles/k3s-install) et le
  playbook [`ansible/playbooks/k3s-install.yml`](../../ansible/playbooks/k3s-install.yml)
  existent.
- Verifie : le playbook de validation passe en `--check`.
- Verifie : aucun secret n'est stocke dans le squelette Ansible versionne.
- Documente : les concepts appris du Sprint 0 dans
  [`docs/concepts-sprint-0.md`](../concepts-sprint-0.md).

## S0-E2 - Kubernetes local

### S0-T4 - Implementer le role `k3s-install`

Etat : `Termine`  
Depend de : `S0-T2`, `S0-T3`

- [x] Definir les variables et versions par defaut.
- [x] Installer k3s sans Flannel.
- [x] Desactiver le controleur NetworkPolicy natif.
- [x] Gerer le service systemd.
- [x] Configurer le kubeconfig avec des permissions minimales.
- [x] Ajouter les handlers necessaires.

#### Criteres d'acceptation

- [x] Le service k3s est actif.
- [x] Flannel n'est pas installe.
- [x] Le controleur NetworkPolicy natif est desactive.
- [x] Le kubeconfig permet d'interroger le cluster.
- [x] Aucun secret n'apparait dans les logs Ansible.

#### Notes de progression

- Initialise : variables par defaut dans
  [`ansible/roles/k3s-install/defaults/main.yml`](../../ansible/roles/k3s-install/defaults/main.yml).
- Initialise : validations d'hypotheses locales dans
  [`ansible/roles/k3s-install/tasks/main.yml`](../../ansible/roles/k3s-install/tasks/main.yml).
- Initialise : handler `restart k3s` dans
  [`ansible/roles/k3s-install/handlers/main.yml`](../../ansible/roles/k3s-install/handlers/main.yml).
- Initialise : playbook de validation
  [`ansible/playbooks/k3s-install.yml`](../../ansible/playbooks/k3s-install.yml).
- Verifie : l'ancien cluster `k3s` local a ete desinstalle proprement via le
  script de desinstallation.
- Verifie : le service `k3s` n'existe plus apres nettoyage.
- Verifie : le kubeconfig utilisateur pointait vers un ancien cluster local et
  n'est plus utilisable tant que `k3s` n'est pas reinstalle.
- Implemente : installation `k3s` via Ansible avec `become: true`.
- Implemente : synchronisation du kubeconfig utilisateur local depuis
  `/etc/rancher/k3s/k3s.yaml`.
- Verifie : `systemctl status k3s` est `active`.
- Verifie : `kubectl --kubeconfig ~/.kube/config get nodes -o wide`
  fonctionne.
- Verifie : un second passage de `ansible-playbook playbooks/k3s-install.yml`
  produit `changed=0`.
- Verifie : `--flannel-backend=none` et `--disable-network-policy` presents dans
  l'unite systemd (`systemctl cat k3s`).
- Verifie : kubeconfig utilisateur en `0600 user:user` — aucun autre compte
  n'a acces.
- Verifie : aucun secret dans les logs Ansible (`grep -iE "password|token|secret"`
  ne retourne rien).
- Point d'attention : le noeud est `NotReady`, coherent — Cilium n'est pas encore
  installe. Etat attendu entre S0-T4 et S0-T6.

#### Risque connu

Les pods peuvent rester en attente avant l'installation de Cilium. Cet etat est
attendu entre `S0-T4` et `S0-T6`.

### S0-T5 - Tester `k3s-install` avec Molecule

Etat : `Termine`  
Depend de : `S0-T4`

- [x] Creer le scenario Molecule.
- [x] Ajouter les tests de convergence.
- [x] Ajouter les verifications k3s et absence de Flannel.
- [x] Executer le test d'idempotence.
- [x] Documenter les limites d'un test systemd en conteneur.

#### Criteres d'acceptation

- [x] Le syntax check reussit.
- [x] `molecule test` reussit.
- [x] Le second passage ne produit aucun changement.
- [x] Les limites du driver de test sont explicites.

#### Notes de progression

- Implemente : scenario
  [`ansible/roles/k3s-install/molecule/default/molecule.yml`](../../ansible/roles/k3s-install/molecule/default/molecule.yml)
  avec driver Docker, `systemd` en conteneur et sequence `syntax ->
  converge -> idempotence -> verify`.
- Implemente : playbook
  [`converge.yml`](../../ansible/roles/k3s-install/molecule/default/converge.yml)
  qui cree un utilisateur `molecule` dedie pour isoler le kubeconfig de test du
  compte local principal.
- Implemente : playbook
  [`verify.yml`](../../ansible/roles/k3s-install/molecule/default/verify.yml)
  qui controle le service `k3s`, les flags `--flannel-backend=none` et
  `--disable-network-policy`, le kubeconfig utilisateur, le symlink `kubectl`
  et la reponse de `kubectl get nodes`.
- Verifie : `docker`, `molecule` et le plugin Docker sont disponibles
  localement.
- Verifie : `molecule syntax`, `molecule converge`, `molecule idempotence`,
  `molecule verify` et `molecule test` reussissent pour le role.
- Verifie : le scenario Docker doit ajouter `--snapshotter=native` dans
  `k3s_install_extra_args` pour contourner la limite `overlayfs` du conteneur
  de test ; cette adaptation reste confinee a Molecule et ne change pas la
  cible du role sur le poste local.
- Risque accepte : un noeud `NotReady` reste acceptable dans ce scenario tant
  que `Cilium` n'est pas encore installe. Le scenario valide le role Ansible,
  pas la disponibilite reseau finale du cluster.

### S0-T6 - Implementer le role `cilium-setup`

Etat : `Termine`  
Depend de : `S0-T5`

- [x] Installer Cilium par Helm en replacement mode.
- [x] Configurer l'IPAM cluster-pool.
- [x] Activer Hubble (relay + UI).
- [x] Ajouter les tests Molecule pertinents.
- [x] Rejouer les validations runtime sur l'hote reel.

#### Criteres d'acceptation

- [x] Le scenario Molecule converge, reste idempotent, et verifie le release
  Helm ainsi que les valeurs critiques du role.
- [x] Sur l'hote reel, `cilium status --wait` confirme un etat sain.
- [x] Sur l'hote reel, les noeuds Kubernetes sont `Ready` et Hubble est actif.
- [x] Sur l'hote reel, `cilium connectivity test` est rejoue ; son echec
  residuel `pod-to-service` est documente comme faux negatif probable de
  validation Hubble / `connectivity test`, non bloquant pour ce lab local
  mono-noeud.
- [x] Sur l'hote reel, le rerun du playbook reste idempotent.

#### Notes de progression

- Implemente : role `ansible/roles/cilium-setup/` (`defaults/main.yml`,
  `tasks/main.yml`) et playbook `ansible/playbooks/cilium-setup.yml`,
  installation via `kubernetes.core.helm` (collection ajoutee a
  `requirements.yml`).
- Implemente : scenario Molecule
  `ansible/roles/cilium-setup/molecule/default/` avec une frontiere de preuve
  explicite :
  - Molecule prouve l'automatisation Ansible (`converge -> idempotence ->
    verify`) et controle le release Helm, les valeurs cles et les objets
    Kubernetes attendus.
  - Les validations de reference du datapath Cilium restent sur l'hote reel
    via `cilium status --wait`, `cilium connectivity test`, Hubble et le
    rerun idempotent du playbook.
- Decide : chart Cilium pinnee en `1.19.5` (derniere stable au moment du
  sprint), IPAM `cluster-pool` sur `10.42.0.0/16` (le defaut interne de k3s,
  pas de reinstallation necessaire), Hubble relay + UI actives.
- Bloque : premiere execution en `CrashLoopBackOff` sur l'agent Cilium.
  Diagnostic mene en chaine : `cilium-operator` restait `Pending`
  (`untolerated taint node.kubernetes.io/disk-pressure`) -> les CRDs Cilium
  n'etaient jamais enregistrees -> l'agent plantait en attendant ces CRDs.
- Cause racine : partition `/` a 94% d'usage, sous le seuil kubelet
  `imagefs.available<15%`. Le poste hebergeait deja d'autres services et
  charges locaux hors perimetre ShopDemo ; aucune de ces donnees n'a ete
  touchee.
- Nettoyage applique sans toucher aux services actifs : conteneurs Docker
  `Exited` supprimes, `docker image prune -a` (images sans conteneur actif
  uniquement, ~1,7 Go), cache `apt`, backends CUDA Ollama inutilises
  supprimes (~3,2 Go, aucun GPU NVIDIA present, service Ollama
  inactif/disabled).
- Point d'attention non resolu : la `data-root` Docker reelle se trouve sur la
  partition systeme alors qu'un autre disque local, beaucoup plus capacitaire,
  est deja monte a cote et quasi vide. Migration de la `data-root` Docker
  reportee par le proprietaire
  (coupure de service le temps du transfert) : a planifier hors urgence.
- Decouverte : un repertoire local de ~5,9 Go ressemble a un duplicata de
  `/var/lib/snapd/` non reference par le `snapd` actif, mais ses fichiers
  ont des dates de modification recentes (avril 2026) ; laisse intact tant
  que son origine n'est pas confirmee par le proprietaire.
- Note technique : `--eviction-pressure-transition-period` (5 min par
  defaut chez kubelet) retarde la levee de `DiskPressure` meme apres un
  nettoyage suffisant ; ne pas conclure trop vite a un nettoyage insuffisant
  sur la base d'une verification immediate.
- Verifie sur l'hote reel : `cilium status --verbose` est sain, Hubble Relay
  est `OK`, le noeud reste `Ready` et les composants `cilium`,
  `cilium-envoy`, `cilium-operator`, `coredns`, `hubble-relay` et
  `hubble-ui` sont prets.
- Verifie sur l'hote reel : `kubectl exec deploy/client -- curl -sv
  http://echo-same-node:8080/` et le meme test depuis `client2` retournent
  `HTTP/1.1 200 OK`.
- Verifie sur l'hote reel : `hubble observe` montre les flows attendus pour
  `pod -> service` (`pre-xlate-fwd`, puis `SYN/SYN-ACK/ACK/FIN` vers le pod
  backend) et pour `pod -> world`.
- Risque accepte : `cilium connectivity test --test no-policies` garde un
  echec residuel sur `no-policies/pod-to-service`. Le trafic reel est
  pourtant valide par `curl` et Hubble ; l'echec est donc traite comme un
  faux negatif probable de validation Hubble / `connectivity test` sur ce
  cluster local mono-noeud, pas comme une panne datapath.
- Etat du suivi : `S0-T6` est `Termine`. La connectivite reelle, Hubble et
  l'idempotence sont verifies ; le faux negatif residuel de
  `cilium connectivity test` est accepte comme risque documente, non
  bloquant pour la suite du sprint.

## S0-E3 - Services du serveur local

### S0-T7 - Implementer `ministack-setup`

Etat : `Termine`  
Depend de : `S0-T3`

- [x] Verifier Docker comme prerequis.
- [x] Deployer MiniStack.
- [x] Creer le profil AWS CLI local.
- [x] Ajouter un test de disponibilite du port 4566.

#### Criteres d'acceptation

- [x] MiniStack demarre automatiquement.
- [x] L'AWS CLI peut interroger l'endpoint local.
- [x] Le role est idempotent.

#### Notes de progression

- Verifie : une synthese de decouverte MiniStack a ete redigee dans
  [`docs/decouverte-ministack.md`](../decouverte-ministack.md) avant
  implementation pour cadrer le modele mental, les limites produit et
  l'usage attendu dans le projet.
- Implemente : role
  [`ansible/roles/ministack-setup/`](../../ansible/roles/ministack-setup)
  et playbook
  [`ansible/playbooks/ministack-setup.yml`](../../ansible/playbooks/ministack-setup.yml)
  avec Docker comme prerequis explicite, image MiniStack pinnee
  `ministackorg/ministack:1.3.70`, endpoint local `localhost:4566` et profil
  AWS CLI `ministack`.
- Implemente : scenario Molecule dedie sous
  [`ansible/roles/ministack-setup/molecule/default/`](../../ansible/roles/ministack-setup/molecule/default)
  pour verifier la convergence du role, l'ecriture du profil AWS CLI, la
  sante `/_ministack/health` et un smoke test `sts get-caller-identity`.
- Verifie : les syntax checks Ansible reussissent pour
  `playbooks/ministack-setup.yml`, `molecule/default/converge.yml` et
  `molecule/default/verify.yml`.
- Verifie sur l'hote reel : premier passage
  `ansible-playbook playbooks/ministack-setup.yml --ask-become-pass`
  reussi (`changed=4`, `failed=0`), conteneur MiniStack demarre, endpoint
  `/_ministack/health` en `200`.
- Verifie sur l'hote reel : `aws --profile ministack --endpoint-url
  http://127.0.0.1:4566 sts get-caller-identity` retourne une identite locale
  synthetique coherente :
  `Account=000000000000`, `Arn=arn:aws:iam::000000000000:root`.
- Verifie sur l'hote reel : second passage du playbook idempotent
  (`changed=0`, `failed=0`).
- Documente : une vue d'architecture locale MiniStack a ete ajoutee dans
  [`ARCHITECTURE.md`](../../ARCHITECTURE.md) avec sa source editable
  [`docs/diagrams/ministack-local-infra.drawio`](../diagrams/ministack-local-infra.drawio).
- Documente : une seconde vue, orientee **cartographie des services AWS
  emules** plutot que flux local, a ete ajoutee dans
  [`ARCHITECTURE.md`](../../ARCHITECTURE.md) avec sa source editable
  [`docs/diagrams/ministack-emulated-services.drawio`](../diagrams/ministack-emulated-services.drawio).
- Documente : `ARCHITECTURE.md` a ete ensuite refactorise en **page maitre
  plus concise**, avec table des matieres cliquable et sous-pages sous
  [`docs/architecture/`](../architecture/README.md), afin de separer vue
  d'ensemble et details pedagogiques.
- Risque accepte : le scenario Molecule a ete prepare et syntax-checke, mais
  n'a pas encore ete execute sur le poste local dans cette passe. La preuve de
  reference retenue pour cloturer `S0-T7` est la validation runtime sur l'hote
  reel + l'idempotence du role.

### S0-T8 - Implementer `cloudflare-tunnel`

Etat : `Termine`  
Depend de : `S0-T3`

- [x] Cadrer l'integration ShopDemo dans un hote ou `cloudflared` est deja installe et utilise.
- [x] Configurer le connecteur local dedie, en laissant les routes metier pour plus tard.
- [x] Proteger le token avec Ansible Vault ou une injection externe.
- [x] Gerer le service systemd.

#### Criteres d'acceptation

- [x] Aucun port entrant public n'est requis.
- [x] Aucun token n'est present dans Git ou les logs.
- [x] Le role est idempotent.

#### Notes de progression

- Verifie : `cloudflared` etait deja installe sur l'hote avant `S0-T8`
  (`/usr/bin/cloudflared`, accessible aussi via `/usr/local/bin/cloudflared`).
- Verifie : d'autres tunnels Cloudflare, non lies a ShopDemo, tournaient deja
  sur cet hote avant tout travail sur `S0-T8`. Le role du sprint ne devait
  donc pas prendre le controle global de `cloudflared`.
- Decide : la sous-etape initiale "Installer `cloudflared`" est annulee pour
  `S0-T8`. Reinstaller ou prendre en charge globalement `cloudflared` via un
  role Ansible d'installation serait intrusif et risquerait de casser des
  tunnels personnels deja en service sur cet hote.
- Corrige : une unite systemd generique `cloudflared.service` preexistante a
  ete renommee localement afin de lever l'ambiguite operationnelle. L'ancienne
  unite a ete retiree.
- Corrige : `cloudflared-update.service` cible maintenant les unites systemd
  encore gerees localement au lieu de l'ancien nom generique supprime.
- Decide : les autres tunnels preexistants, y compris ceux exploites hors
  `systemd`, restent hors perimetre de `S0-T8`.
- Implemente : nouveau playbook
  [`ansible/playbooks/cloudflare-tunnel.yml`](../../ansible/playbooks/cloudflare-tunnel.yml)
  et role [`ansible/roles/cloudflare-tunnel/`](../../ansible/roles/cloudflare-tunnel)
  pour la **surcouche ShopDemo** uniquement. Le role ne reinstalle pas
  `cloudflared` et ne prend pas en charge les tunnels personnels existants.
- Implemente : le role rend un fichier d'environnement
  `/etc/cloudflared/shopdemo.env` (token externe) et une unite dediee
  `cloudflared-shopdemo.service`, avec un port de metrics propre
  `127.0.0.1:20245`.
- Decide : pour ce lab, le compromis de secret retenu est :
  - persistance runtime dans `/etc/cloudflared/shopdemo.env` ;
  - export shell `SHOPDEMO_TUNNEL_TOKEN` uniquement temporaire pour rejouer
    Ansible ;
  - recharge a la demande via
    `export SHOPDEMO_TUNNEL_TOKEN="$(sudo awk -F= '/^TUNNEL_TOKEN=/{print $2}' /etc/cloudflared/shopdemo.env)"`.
- Implemente : variables de routes futures `argocd`, `grafana`, `gitea`
  documentees dans les defaults du role comme **routes planifiees** cote
  Cloudflare, sans pretendre que les origins locales existent deja.
- Implemente : scenario Molecule minimal sous
  [`ansible/roles/cloudflare-tunnel/molecule/default/`](../../ansible/roles/cloudflare-tunnel/molecule/default)
  pour verifier le rendu du fichier d'environnement, de l'unite `systemd` et
  les permissions associees sans takeover du vrai `systemd` de l'hote.
- Verifie : `ansible-playbook --syntax-check playbooks/cloudflare-tunnel.yml`
  reussit depuis le repertoire [`ansible/`](../../ansible).
- Verifie : `molecule test` reussit pour
  [`ansible/roles/cloudflare-tunnel/`](../../ansible/roles/cloudflare-tunnel)
  avec un binaire `cloudflared` de test et une gestion `systemd` desactivee
  dans le conteneur Molecule ; l'objectif est de prouver le rendu, les
  permissions et l'idempotence du role, pas une connexion reelle a Cloudflare.
- Documente : l'architecture locale a ete completee avec le schema
  [`docs/diagrams/cloudflare-tunnels-local.drawio`](../diagrams/cloudflare-tunnels-local.drawio)
  et son export SVG, centres sur le pattern ShopDemo et non sur l'inventaire
  detaille des usages personnels de l'hote.
- Risque accepte : les tokens restent inline pour certains tunnels existants
  hors perimetre ShopDemo. Ce point est documente comme hygiene restante, mais
  n'est pas traite dans cette phase de prerequis.
- Etat reel : l'integration specifique ShopDemo est maintenant implemente sur
  le plan Ansible et documentaire, avec tunnel Cloudflare `shopdemo` cree,
  token externe charge hors Git, service `cloudflared-shopdemo.service`
  actif sur l'hote et statut `Healthy` confirme cote Cloudflare.
- Verifie : rerun manuel du playbook avec vrai token, sans changement
  (`changed=0`), ce qui confirme l'idempotence utile sur l'hote reel.
- Verifie : le tunnel `shopdemo` est `Healthy` dans le dashboard Cloudflare ;
  la remontee du connecteur est donc validee.

#### Suite hors cloture de `S0-T8`

- [ ] Quand les services existeront reellement, raccorder les routes
  Cloudflare aux vraies origins locales (`argocd`, `grafana`, `gitea`).
- [ ] Rejouer au besoin le playbook avec un token temporairement recharge :

  ```bash
  export SHOPDEMO_TUNNEL_TOKEN="$(sudo awk -F= '/^TUNNEL_TOKEN=/{print $2}' /etc/cloudflared/shopdemo.env)"
  cd ansible
  ansible-playbook playbooks/cloudflare-tunnel.yml \
    -e cloudflare_tunnel_shopdemo_token="$SHOPDEMO_TUNNEL_TOKEN"
  ```

### S0-T9 - Implementer `gitlab-runner`

Etat : `Planifie`  
Depend de : `S0-T3`

- [ ] Installer GitLab Runner.
- [ ] Configurer le Docker executor.
- [ ] Externaliser le token d'enregistrement.
- [ ] Preparer la reutilisation sur l'EC2 bootstrap.

#### Criteres d'acceptation

- [ ] Le runner est enregistre sans secret versionne.
- [ ] Un job de validation local peut etre execute.
- [ ] Le role est idempotent.

### S0-T10 - Implementer `node-hardening`

Etat : `Planifie`  
Depend de : `S0-T3`

- [ ] Integrer `dev-sec.os-hardening`.
- [ ] Definir les exceptions requises par k3s et Docker.
- [ ] Tester la connectivite et les services apres durcissement.
- [ ] Documenter les controles CIS couverts.

#### Criteres d'acceptation

- [ ] Le durcissement ne casse pas k3s, Docker ou l'acces d'administration.
- [ ] Les exceptions sont justifiees.
- [ ] Le role est idempotent.

## S0-E4 - Orchestration et frontiere Terraform/Ansible

### S0-T11 - Composer les playbooks locaux

Etat : `Planifie`  
Depend de : `S0-T6`, `S0-T7`, `S0-T8`, `S0-T9`, `S0-T10`

- [ ] Creer `playbooks/bootstrap.yml`.
- [ ] Definir un ordre explicite entre les roles.
- [ ] Creer `playbooks/harden.yml`.
- [ ] Creer `playbooks/teardown.yml` avec des garde-fous.

#### Criteres d'acceptation

- [ ] Le bootstrap complet est reproductible.
- [ ] Le second passage est idempotent.
- [ ] Le teardown exige une confirmation explicite.
- [ ] Les actions destructives sont documentees.

### S0-T12 - Preparer les playbooks AWS futurs

Etat : `Planifie`  
Depend de : `S0-T3`

- [ ] Creer `runner-setup.yml`.
- [ ] Creer `rds-setup.yml`.
- [ ] Creer `gitea-setup.yml`.
- [ ] Definir les variables et interfaces sans appeler AWS.

#### Criteres d'acceptation

- [ ] Terraform reste responsable du provisioning.
- [ ] Ansible reste responsable de la configuration.
- [ ] Les secrets sont lus depuis une source externe.
- [ ] Aucun appel AWS payant n'est necessaire pour la validation initiale.

## S0-E5 - Validation et cloture

### S0-T13 - Valider et documenter le Sprint 0

Etat : `Planifie`  
Depend de : `S0-T5` a `S0-T12`

- [ ] Executer les syntax checks.
- [ ] Executer les tests Molecule.
- [ ] Verifier l'idempotence du bootstrap.
- [ ] Documenter installation, utilisation, rollback et nettoyage.
- [ ] Renseigner les preuves importantes.
- [ ] Preparer le fichier de suivi du Sprint 1.

#### Criteres d'acceptation

- [ ] Tous les roles applicables passent leurs validations.
- [ ] Les validations non executees sont justifiees.
- [ ] Les risques residuels sont documentes.
- [ ] La table de suivi de `README.md` et `CURRENT.md` refletent l'etat reel.

## Preuves

| Controle | Etat | Preuve |
|---|---|---|
| Structure de suivi | Verifie | Documents sous `docs/` |
| Syntaxe Ansible | Planifie | A renseigner |
| Tests Molecule | Planifie | A renseigner |
| Idempotence bootstrap | Planifie | A renseigner |
| Connectivite k3s/Cilium | Planifie | A renseigner |

## Decisions et ecarts

Aucun ecart avec `ARCHITECTURE.md` identifie a ce stade.
