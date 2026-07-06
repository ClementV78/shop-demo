# Travail en cours

## Sprint actif

Sprint 0 - Ansible et fondations bootstrap.

Suivi detaille :
[`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md).

## Taches actives

| ID | Tache | Etat | Prochaine action |
|---|---|---|---|
| S0-T10 | Implementer `node-hardening` | Planifie | Cadrer l'integration `dev-sec.os-hardening`, les exceptions `k3s`/Docker et la strategie de validation sans casser le lab local |

Taches deja terminees dans le sprint :
`S0-T1`, `S0-T4`, `S0-T5`, `S0-T6`, `S0-T7`, `S0-T8`, `S0-T9`.

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
- La branche GitHub `test/gitlab-runner-smoke` a ete mergee dans `master`
  via la PR `#1`. En reprise de session, repartir de `master` a jour avant
  tout nouveau travail.

## Prochaine reprise recommandee

1. `git switch master`
2. `git pull origin master`
3. Relire `S0-T10` dans [`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md)
4. Cadrer le hardening avant code :
   - perimetre exact de `dev-sec.os-hardening`
   - exceptions necessaires pour `k3s`, Docker, `ufw`, Cilium et le lab local
   - strategie de validation sans casser l'hote personnel

## Rappel de maintenance

- `docs/CURRENT.md` doit rester court et oriente reprise de session.
- L'historique detaille, les preuves et les notes longues vivent dans le
  fichier de sprint, les ADR et les documents techniques dedies.
