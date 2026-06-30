# Travail en cours

## Sprint actif

Sprint 0 - Ansible et fondations bootstrap.

Suivi detaille :
[`docs/sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md).

## Taches actives

| ID | Tache | Etat | Prochaine action |
|---|---|---|---|
| S0-T1 | Initialiser le socle du depot | En cours | Verifier le contenu minimal du `README.md` et preparer le premier commit |
| S0-T4 | Implementer `k3s-install` | Termine | Utiliser ce role comme base des tests Molecule |
| S0-T6 | Implementer `cilium-setup` | Planifie | Poser le role, installer Cilium en replacement mode et verifier le passage du noeud a `Ready` |

## Blocages

Aucun blocage connu.

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
- Le kubeconfig utilisateur `xclem` est maintenant synchronise depuis la source
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

## Next Step

1. Demarrer `S0-T6` avec le role `cilium-setup`.
2. Installer Cilium en replacement mode, activer Hubble et observer le
   passage vers un noeud `Ready`.
3. Preparer ensuite les tests Molecule pertinents pour `cilium-setup`.
