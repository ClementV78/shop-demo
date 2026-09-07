# Travail en cours

## Sprint actif

Sprint 0 - Ansible et fondations bootstrap : `Termine`.
Sprint 1 - Argo CD et base GitOps locale : `En cours`.

Suivi detaille :
[`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md) et
[`docs/sprints/sprint-1-gitops-local.md`](sprints/sprint-1-gitops-local.md).

## Prochaine tache

| ID | Tache | Etat | Prochaine action |
|---|---|---|---|
| S1-T2 | Installer Argo CD sur le lab local | Planifie | Preparer l'installation, les manifests Argo CD et les validations sans exposer de secret |

Taches terminees du Sprint 0 :
`S0-T1`, `S0-T2`, `S0-T3`, `S0-T4`, `S0-T5`, `S0-T6`, `S0-T7`, `S0-T8`,
`S0-T9`, `S0-T10`, `S0-T11`, `S0-T12`, `S0-T13`.

Taches terminees du Sprint 1 :
`S1-T1`.

## Blocages

Aucun blocage actif.

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

## Documents de reference immediats

- Architecture cible : [`ARCHITECTURE.md`](../ARCHITECTURE.md)
- Sprint 0 detaille : [`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md)
- Sprint 1 detaille : [`docs/sprints/sprint-1-gitops-local.md`](sprints/sprint-1-gitops-local.md)
- Comment ca marche techniquement : [`docs/comment-ca-marche.md`](comment-ca-marche.md)
- Structure GitOps : [`docs/gitops-structure.md`](gitops-structure.md)
- Concepts Sprint 1 : [`docs/concepts-sprint-1.md`](concepts-sprint-1.md)
- Decision CI GitLab : [`docs/adr/ADR-001-gitlab-com-for-ci.md`](adr/ADR-001-gitlab-com-for-ci.md)
- Decision retrait forge self-hosted : `ADR-002`
- Decisions structurantes Sprint 0 / S1-T1 :
  [`ADR-003`](adr/ADR-003-separate-bootstrap-and-workload-states.md),
  [`ADR-004`](adr/ADR-004-use-k3s-cilium-replacement-mode.md),
  [`ADR-005`](adr/ADR-005-use-ministack-for-local-aws-validation.md),
  [`ADR-006`](adr/ADR-006-structure-gitops-platform-apps-environments.md)
- Delivery / GitOps : [`docs/architecture/05-delivery-gitops.md`](architecture/05-delivery-gitops.md)

## Dernieres actions utiles

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
- Verifie pour `S0-T12` : `syntax-check` OK sur les trois playbooks,
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
- La branche GitHub `test/gitlab-runner-smoke` a ete mergee dans `master`
  via la PR `#1`. En reprise de session, repartir de `master` a jour avant
  tout nouveau travail.

## Prochaine reprise recommandee

1. Demarrer `S1-T2` : installer Argo CD sur le lab local avec une procedure
   documentee et reversible.
2. Verifier que le namespace `argocd` existe ou sera cree par le chemin GitOps
   avant l'installation.
3. Definir les premieres commandes de validation : pods Argo CD, service,
   acces UI/API et absence de secret versionne.

## Rappel de maintenance

- `docs/CURRENT.md` doit rester court et oriente reprise de session.
- L'historique detaille, les preuves et les notes longues vivent dans le
  fichier de sprint, les ADR et les documents techniques dedies.
