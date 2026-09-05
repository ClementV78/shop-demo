# Cours Accelere Ansible Avec ShopDemo

## Objectif

Ce document donne une lecture rapide d'Ansible a partir du Sprint 0 de
ShopDemo. L'objectif n'est pas de couvrir tout Ansible, mais de comprendre les
concepts necessaires pour lire, modifier et valider les playbooks du projet.

Source de verite projet :

- architecture cible : [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- structure Ansible detaillee : [`ansible-structure.md`](ansible-structure.md)
- suivi courant : [`CURRENT.md`](CURRENT.md)

## 1. Le Modele Mental

Ansible sert a declarer l'etat attendu d'une machine, puis a appliquer cet etat
de maniere reproductible.

Dans ShopDemo :

```text
inventory -> playbook -> role -> tasks -> modules -> host
```

Lecture :

- `inventory` dit quelles machines cibler ;
- `playbook` dit quoi executer et dans quel ordre ;
- `role` regroupe une responsabilite reutilisable ;
- `tasks` liste les actions ;
- `modules` font le vrai travail : `package`, `service`, `copy`, `template`,
  `command`, `assert`, etc. ;
- `host` est la machine configuree.

Le principe important : un playbook ne devrait pas etre un script shell long.
Il doit assembler des roles lisibles, idempotents et testables.

## 2. Inventaire : Qui Est Cible

Le Sprint 0 cible d'abord le serveur local Ubuntu.

Fichier important :
[`../ansible/inventory/local.yml`](../ansible/inventory/local.yml)

Commande utile :

```bash
cd ansible
ansible-inventory --graph
```

Ce que tu dois verifier :

- le groupe `local` existe ;
- `localhost` est bien resolu ;
- l'execution ne depend pas d'une machine cachee ou d'un nom implicite.

Plus tard, [`../ansible/inventory/aws_ec2.yml`](../ansible/inventory/aws_ec2.yml)
servira a decouvrir des EC2 deja creees par Terraform. C'est volontaire :
Terraform provisionne, Ansible configure.

## 3. Variables : Rendre Le Comportement Parametrable

Les variables communes vivent dans
[`../ansible/group_vars/all.yml`](../ansible/group_vars/all.yml).

Exemple :

```yaml
bootstrap_enable_cloudflare_tunnel: false
bootstrap_enable_gitlab_runner: false

teardown_confirm: false
teardown_remove_k3s: false
teardown_remove_ministack: false
```

Ces valeurs montrent une bonne pratique : les actions sensibles ou dependantes
de secrets sont desactivees par defaut.

Mental model :

- une variable globale exprime une politique projet ;
- une variable de role exprime un comportement technique local au role ;
- un secret ne doit pas etre versionne dans Git.

Exemple dans `k3s-install` :
[`../ansible/roles/k3s-install/defaults/main.yml`](../ansible/roles/k3s-install/defaults/main.yml)

```yaml
k3s_version: "v1.33.1+k3s1"
k3s_install_extra_args:
  - "--flannel-backend=none"
  - "--disable-network-policy"
  - "--disable-kube-proxy"
```

Ici, changer `k3s_version` doit suffire a piloter une montee de version. Les
flags reseau rendent explicite le choix architectural : pas de Flannel, Cilium
porte le reseau.

## 4. Playbooks : Orchestrer Sans Cacher

Un playbook assemble les roles.

Exemple :
[`../ansible/playbooks/bootstrap.yml`](../ansible/playbooks/bootstrap.yml)

```yaml
- name: Bootstrap the local ShopDemo lab
  hosts: local
  gather_facts: true
  become: false

  roles:
    - role: k3s-install
    - role: cilium-setup
    - role: ministack-setup
    - role: node-hardening
    - role: cloudflare-tunnel
      when: bootstrap_enable_cloudflare_tunnel | bool
    - role: gitlab-runner
      when: bootstrap_enable_gitlab_runner | bool
```

Ce playbook est lisible parce qu'il montre l'ordre metier :

1. installer `k3s` ;
2. installer `Cilium` ;
3. installer `MiniStack` ;
4. appliquer le hardening local minimal ;
5. activer les integrations optionnelles seulement si demande.

Le `when` est un garde-fou. Il evite qu'un playbook de bootstrap basique tente
d'utiliser un token Cloudflare ou GitLab absent.

## 5. Roles : Une Responsabilite Claire

Un role est une unite reutilisable.

Exemple :

```text
ansible/roles/k3s-install/
├── defaults/main.yml
├── handlers/main.yml
└── tasks/main.yml
```

Dans ce projet :

- `defaults/main.yml` contient les valeurs par defaut ;
- `tasks/main.yml` contient la logique ;
- `handlers/main.yml` contient les actions declenchees sur changement.

Bonne regle : un role doit pouvoir etre explique en une phrase.

Exemples :

- `k3s-install` installe et expose un cluster `k3s` local sans CNI integre ;
- `cilium-setup` installe Cilium sur ce cluster ;
- `ministack-setup` lance un endpoint AWS-like local ;
- `cloudflare-tunnel` gere uniquement le tunnel ShopDemo, sans toucher aux
  autres tunnels de l'hote ;
- `gitlab-runner` installe et enregistre un runner GitLab si un token externe
  est fourni.

## 6. Tasks Et Modules : Declarer L'Etat Attendu

Une task appelle un module Ansible.

Exemples tires de `k3s-install` :
[`../ansible/roles/k3s-install/tasks/main.yml`](../ansible/roles/k3s-install/tasks/main.yml)

```yaml
- name: Check whether k3s is already installed
  ansible.builtin.stat:
    path: /usr/local/bin/k3s
  register: k3s_binary
```

Cette task lit l'etat reel. Elle ne modifie rien. Le resultat est stocke dans
`k3s_binary`.

```yaml
- name: Ensure required package for installer is present
  become: true
  ansible.builtin.package:
    name: curl
    state: present
```

Cette task declare : "`curl` doit etre installe". Si `curl` est deja present,
Ansible ne change rien.

```yaml
- name: Ensure k3s service is enabled and started
  become: true
  ansible.builtin.service:
    name: k3s
    enabled: true
    state: started
```

Cette task declare deux etats :

- le service demarre maintenant ;
- le service redemarrera au boot.

Ce n'est pas juste une commande imperative. C'est une declaration d'etat.

## 7. Idempotence : Le Test Le Plus Important

L'idempotence veut dire : rejouer le meme playbook ne doit pas refaire le
travail inutilement.

Exemple mental :

```text
premier run  -> installe k3s -> changed
second run   -> k3s deja conforme -> ok
```

Dans `k3s-install`, l'idempotence vient notamment de cette sequence :

```text
stat /usr/local/bin/k3s
-> read current version
-> detect flags drift
-> compute k3s_needs_install
-> install only when k3s_needs_install == true
```

Le role ne lance pas l'installation aveuglement. Il lit d'abord l'etat reel,
puis decide si une action est necessaire.

Commande utile pour une validation non destructive :

```bash
cd ansible
ansible-playbook --check playbooks/bootstrap.yml
```

Limite importante : `--check` predit les changements, mais ne remplace pas
toujours un run reel. Certaines validations runtime sont volontairement
desactivees en check mode quand l'etat attendu n'existe pas encore.

## 8. `become`: Passer Root Seulement Quand Necessaire

`become: true` permet d'executer une task avec des privileges eleves.

Dans ShopDemo, c'est necessaire pour :

- installer des paquets ;
- ecrire dans `/etc` ;
- gerer `systemd` ;
- lire le kubeconfig systeme de `k3s`.

Mais le playbook `bootstrap.yml` garde `become: false` au niveau global. Chaque
task ou role eleve ses privileges seulement quand c'est utile.

Pourquoi c'est mieux :

- moindre privilege ;
- moins de risque sur l'hote personnel ;
- plus facile de voir quelles actions touchent le systeme.

## 9. Handlers : Reagir Aux Changements

Un handler est une action executee seulement si une task le notifie.

Exemple :
[`../ansible/roles/k3s-install/handlers/main.yml`](../ansible/roles/k3s-install/handlers/main.yml)

```yaml
- name: restart k3s
  ansible.builtin.service:
    name: k3s
    state: restarted
```

Dans le role, l'installation de `k3s` fait :

```yaml
notify: restart k3s
```

Interet :

- le service n'est pas redemarre si rien ne change ;
- si plusieurs tasks notifient le meme handler, il ne tourne qu'une fois a la
  fin du play ;
- les redemarrages deviennent previsibles.

## 10. Assertions : Echouer Tot

Les assertions verifient que le contexte est compatible avant de modifier la
machine.

Exemple :

```yaml
- name: Assert supported host for k3s local bootstrap
  ansible.builtin.assert:
    that:
      - ansible_facts["system"] == "Linux"
      - ansible_facts["service_mgr"] == "systemd"
      - ansible_facts["os_family"] == "Debian"
```

Cette task protege le role : il cible actuellement un hote Linux Debian-family
avec `systemd`. Sans cette assertion, l'erreur arriverait plus tard, souvent de
maniere moins claire.

Bonne pratique : les hypotheses fortes doivent etre codees en assertions.

## 11. Molecule : Tester Un Role En Isolation

Molecule lance un environnement de test, joue le role, verifie le resultat,
puis teste l'idempotence.

Exemple :

```bash
cd ansible/roles/k3s-install
molecule test
```

Dans ShopDemo, Molecule sert a verifier les roles sans casser l'hote local.
Mais il a des limites :

- un conteneur Docker n'est pas un vrai serveur complet ;
- `systemd`, `k3s`, Cilium et le reseau kernel peuvent se comporter differemment
  du runtime reel ;
- certaines validations doivent rester sur l'hote local ou plus tard sur AWS.

Le bon modele :

```text
Molecule -> valide le comportement du role
host reel -> valide le runtime
AWS reel -> valide les services manages et integrations cloud
```

## 12. Frontiere Terraform / Ansible

Le projet garde une separation stricte :

```text
Terraform cree l'infrastructure.
Ansible configure ce qui existe deja.
```

Exemples futurs de `S0-T12` :

- Terraform creera l'EC2 runner ; Ansible installera Docker et GitLab Runner ;
- Terraform creera RDS ; Ansible creera les databases et users applicatifs ;
- Terraform/Helm deployeront Gitea ; Ansible creera l'organisation, les repos
  et le token bot GitOps.

Cette separation evite deux problemes classiques :

- Terraform qui devient un outil de configuration imperative ;
- Ansible qui commence a creer de l'infrastructure cloud difficile a tracer.

## 13. Commandes A Connaitre

Lire la configuration active :

```bash
cd ansible
ansible-config dump --only-changed
```

Voir les hosts resolus :

```bash
cd ansible
ansible-inventory --graph
```

Verifier la syntaxe d'un playbook :

```bash
cd ansible
ansible-playbook --syntax-check playbooks/bootstrap.yml
```

Simuler sans appliquer :

```bash
cd ansible
ansible-playbook --check playbooks/bootstrap.yml
```

Jouer un role optionnel avec une variable explicite :

```bash
cd ansible
ansible-playbook playbooks/bootstrap.yml \
  -e bootstrap_enable_cloudflare_tunnel=true
```

Attention : les roles optionnels peuvent demander des secrets externes. Ne les
versionne jamais dans Git.

## 14. Checklist De Revue Ansible

Avant d'accepter un role ou un playbook, verifie :

- la responsabilite du role est claire ;
- les preconditions importantes sont exprimees avec `assert` ;
- les secrets ne sont pas dans Git ;
- les actions destructives sont derriere une confirmation explicite ;
- les tasks utilisent des modules declaratifs quand c'est possible ;
- les commandes imperatives ont un `changed_when`, un `failed_when` ou un
  `when` justifie ;
- le role est rejouable sans changement inutile ;
- `--syntax-check` passe ;
- `--check` est utile ou ses limites sont documentees ;
- Molecule existe quand le role a assez de logique pour meriter un test isole.

## 15. Ce Qu'il Faut Retenir

Ansible n'est pas seulement un lanceur de commandes SSH. Dans ce projet, il
sert a transformer le serveur local, puis certains composants AWS futurs, en
systemes configurables, rejouables et documentes.

Le niveau attendu pour ShopDemo :

- savoir lire un playbook ;
- savoir trouver les variables qui pilotent un role ;
- comprendre pourquoi une task change ou ne change pas l'etat ;
- distinguer validation syntaxique, check mode, Molecule et validation runtime ;
- garder la frontiere claire entre Terraform et Ansible.
