# Travail en cours

## Sprint actif

Sprint 0 - Ansible et fondations bootstrap.

Suivi detaille :
[`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md).

## Taches actives

| ID | Tache | Etat | Prochaine action |
|---|---|---|---|
| S0-T12 | Preparer les playbooks AWS futurs | En cours | Cadrer `runner-setup.yml`, `rds-setup.yml` et `gitea-setup.yml` sans appel AWS, puis definir leurs interfaces d'entree |

Taches deja terminees dans le sprint :
`S0-T1`, `S0-T4`, `S0-T5`, `S0-T6`, `S0-T7`, `S0-T8`, `S0-T9`, `S0-T10`, `S0-T11`.

## Blocages

- Aucun blocage actif.

Points de vigilance non bloquants :
- `cloudflared` et d'autres tunnels preexistaient deja sur l'hote ; le role
  ShopDemo reste volontairement non intrusif.
- `metrics-server` et le job `helm-install-traefik` restent en erreur sur le
  lab local pour des raisons hors perimetre `S0-T6`.
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

## Documents de reference immediats

- Architecture cible : [`ARCHITECTURE.md`](../ARCHITECTURE.md)
- Sprint 0 detaille : [`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md)
- Decision CI GitLab : [`docs/adr/ADR-001-gitlab-com-for-ci.md`](adr/ADR-001-gitlab-com-for-ci.md)
- Delivery / GitOps : [`docs/architecture/05-delivery-gitops.md`](architecture/05-delivery-gitops.md)

## Dernieres actions utiles

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

1. `git switch master`
2. `git pull origin master`
3. Relire `S0-T12` dans [`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md)
4. Cadrer les playbooks AWS futurs :
   - `ansible/playbooks/runner-setup.yml`
   - `ansible/playbooks/rds-setup.yml`
   - `ansible/playbooks/gitea-setup.yml`
   - leurs variables d'entree sans appel AWS direct

## Rappel de maintenance

- `docs/CURRENT.md` doit rester court et oriente reprise de session.
- L'historique detaille, les preuves et les notes longues vivent dans le
  fichier de sprint, les ADR et les documents techniques dedies.
