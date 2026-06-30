# Sprint 0 - Ansible et fondations bootstrap

## Objectif

Rendre le serveur Ubuntu local reproductible avec Ansible et poser la frontiere
Terraform/Ansible reutilisee pour le runner EC2, RDS et Gitea.

Conception cible :
[`ARCHITECTURE.md - Sprint 0`](../../ARCHITECTURE.md#sprint-0--ansible--provisioning-local--fondations-bootstrap).

## Tableau de bord

| ID | Tache | Etat | Depend de |
|---|---|---|---|
| S0-T1 | Initialiser le socle du depot | Termine | - |
| S0-T2 | Verifier l'environnement de travail | Termine | S0-T1 |
| S0-T3 | Creer le squelette Ansible | Termine | S0-T1 |
| S0-T4 | Implementer `k3s-install` | Termine | S0-T2, S0-T3 |
| S0-T5 | Tester `k3s-install` avec Molecule | Termine | S0-T4 |
| S0-T6 | Implementer `cilium-setup` | Planifie | S0-T5 |
| S0-T7 | Implementer `ministack-setup` | Planifie | S0-T3 |
| S0-T8 | Implementer `cloudflare-tunnel` | Planifie | S0-T3 |
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
- Implemente : synchronisation du kubeconfig utilisateur `xclem` depuis
  `/etc/rancher/k3s/k3s.yaml`.
- Verifie : `systemctl status k3s` est `active`.
- Verifie : `kubectl --kubeconfig /home/xclem/.kube/config get nodes -o wide`
  fonctionne.
- Verifie : un second passage de `ansible-playbook playbooks/k3s-install.yml`
  produit `changed=0`.
- Verifie : `--flannel-backend=none` et `--disable-network-policy` presents dans
  l'unite systemd (`systemctl cat k3s`).
- Verifie : kubeconfig utilisateur en `0600 xclem:xclem` — aucun autre compte
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
  compte local `xclem`.
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

Etat : `Planifie`  
Depend de : `S0-T5`

- [ ] Installer Cilium par Helm en replacement mode.
- [ ] Configurer l'IPAM cluster-pool.
- [ ] Activer Hubble.
- [ ] Attendre la disponibilite des composants.
- [ ] Ajouter les tests Molecule pertinents.

#### Criteres d'acceptation

- [ ] Les pods Cilium sont disponibles.
- [ ] Les noeuds Kubernetes sont `Ready`.
- [ ] Hubble est actif.
- [ ] Un pod de test dispose de connectivite reseau.
- [ ] Le role est idempotent.

## S0-E3 - Services du serveur local

### S0-T7 - Implementer `ministack-setup`

Etat : `Planifie`  
Depend de : `S0-T3`

- [ ] Installer et configurer Docker.
- [ ] Deployer MiniStack.
- [ ] Creer le profil AWS CLI local.
- [ ] Ajouter un test de disponibilite du port 4566.

#### Criteres d'acceptation

- [ ] MiniStack demarre automatiquement.
- [ ] L'AWS CLI peut interroger l'endpoint local.
- [ ] Le role est idempotent.

### S0-T8 - Implementer `cloudflare-tunnel`

Etat : `Planifie`  
Depend de : `S0-T3`

- [ ] Installer `cloudflared`.
- [ ] Configurer les routes locales prevues.
- [ ] Proteger le token avec Ansible Vault ou une injection externe.
- [ ] Gerer le service systemd.

#### Criteres d'acceptation

- [ ] Aucun port entrant public n'est requis.
- [ ] Aucun token n'est present dans Git ou les logs.
- [ ] Le role est idempotent.

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
- [ ] `ROADMAP.md` et `CURRENT.md` refletent l'etat reel.

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
