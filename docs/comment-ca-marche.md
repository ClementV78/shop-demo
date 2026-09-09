# Comment ca marche techniquement

[Pourquoi ce document](#pourquoi-ce-document-existe) · [Vue d'ensemble](#vue-densemble-actuelle) · [Sprint 0](#sprint-0---comment-le-lab-local-est-construit) · [S1-T1](#s1-t1---comment-la-base-gitops-commence) · [S1-T2](#s1-t2---comment-argo-cd-est-installe-et-synchronise) · [S1-T3](#s1-t3---comment-les-namespaces-applicatifs-et-lisolation-arrivent) · [S1-T4](#s1-t4---comment-une-application-est-decrite-une-fois) · [S1-T5](#s1-t5---comment-les-applications-cessent-detre-ecrites-a-la-main) · [S1-T6](#s1-t6---comment-la-production-se-separe-de-staging) · [S1-T7](#s1-t7---comment-on-revient-en-arriere) · [S2-T1](#s2-t1---comment-linfrastructure-aws-commence) · [En entretien](#ce-quil-faut-savoir-raconter-en-entretien) · [Ou aller ensuite](#ou-aller-ensuite)

## Pourquoi ce document existe

Les documents d'architecture expliquent **ce que le projet veut construire**.
Les documents de sprint expliquent **ce qui est fait et valide**. Celui-ci sert
a expliquer **comment on l'a fait techniquement**, avec les fichiers reels du
repo comme support.

L'objectif est de pouvoir parler du projet en entretien sans rester au niveau
"j'ai installe k3s, Cilium et GitOps". Il faut pouvoir raconter le chemin :

> J'ai d'abord rendu le serveur local reproductible avec Ansible. Ensuite, j'ai
> commence a deplacer l'intention Kubernetes dans Git, pour preparer Argo CD.

Ce document sera complete sprint par sprint.

## Vue d'ensemble actuelle

<p align="center">
  <img src="diagrams/comment-ca-marche-s0-s1.svg" alt="Comment ca marche du Sprint 0 au Sprint 1" width="1050">
</p>

> Source editable :
> [`diagrams/comment-ca-marche-s0-s1.drawio`](diagrams/comment-ca-marche-s0-s1.drawio).

Le projet part d'un serveur Ubuntu local. Au lieu de le configurer a la main,
on decrit sa configuration avec Ansible. Le point important n'est pas seulement
"installer des outils". Le point important est de rendre cette installation
rejouable, lisible et testable.

Le Sprint 0 fabrique donc un lab local : `k3s` fournit l'API Kubernetes,
`Cilium` fournit le reseau des pods, `MiniStack` aide a tester des flux AWS en
local, `cloudflare-tunnel` prepare l'exposition future d'outils, et
`gitlab-runner` permet de raccorder le lab a la CI.

`S1-T1` ne deploie pas encore Argo CD. Il commence par une etape plus simple :
mettre l'etat Kubernetes desire dans [`../gitops/`](../gitops/). A ce stade,
Kustomize sert seulement a rendre les YAML localement pour verifier ce qui
serait applique plus tard.

Les chapitres qui suivent sont ecrits dans l'ordre du projet et chacun decrit
l'etat au moment de la tache. La section `S1-T1` decrit donc volontairement
l'etat d'avant Argo CD : la progression fait partie de l'explication, et lire
la suite corrige d'elle meme ce qui n'etait alors pas encore vrai.

Etat au 2026-09-09 : le Sprint 1 est clos, la chaine complete fonctionne. Un
merge dans `main` deploie staging automatiquement, seule la pose d'un tag
semver promeut en production, et le retour arriere a ete execute sur un
incident reel plutot que decrit. Le Sprint 2 a commence par `S2-T1`, qui pose
la structure Terraform sans creer la moindre ressource AWS.

## Sprint 0 - Comment le lab local est construit

### Le point d'entree : un playbook qui raconte l'ordre

Le fichier [`ansible/playbooks/bootstrap.yml`](../ansible/playbooks/bootstrap.yml)
est le point d'entree principal du lab local.

Il ne contient pas toute la logique. Il raconte plutot l'ordre dans lequel les
briques doivent arriver :

```yaml
roles:
  - role: k3s-install
  - role: cilium-setup
    cilium_runtime_validation_enabled: "{{ not ansible_check_mode }}"
  - role: ministack-setup
    ministack_runtime_validation_enabled: "{{ not ansible_check_mode }}"
  - role: node-hardening
  - role: cloudflare-tunnel
    when: bootstrap_enable_cloudflare_tunnel | bool
  - role: gitlab-runner
    when: bootstrap_enable_gitlab_runner | bool
```

La logique est volontairement separee :

- le playbook orchestre ;
- chaque role sait configurer une responsabilite technique ;
- les roles optionnels restent desactives par defaut quand ils exigent un
  secret externe.

C'est une bonne pratique importante : si `bootstrap.yml` contenait directement
toutes les tasks k3s, Cilium, MiniStack, tunnel et runner, il serait plus dur a
relire, plus dur a tester, et plus risque a rejouer.

```mermaid
flowchart LR
  B[bootstrap.yml] --> K[k3s-install]
  K --> C[cilium-setup]
  C --> M[ministack-setup]
  M --> H[node-hardening]
  H -. si active .-> T[cloudflare-tunnel]
  H -. si active .-> R[gitlab-runner]
```

### Comment Ansible sait ou agir

Le lab local est cible par un inventaire tres simple :
[`ansible/inventory/local.yml`](../ansible/inventory/local.yml).

```yaml
all:
  children:
    local:
      hosts:
        localhost:
          ansible_connection: local
          ansible_host: 127.0.0.1
```

Cette configuration dit : "le groupe `local` pointe vers la machine courante".
Ansible ne se connecte pas en SSH a une autre machine ; il agit localement.

Le fichier [`ansible/ansible.cfg`](../ansible/ansible.cfg) donne ensuite les
regles de base : quel inventaire charger, ou trouver les roles, quelles
collections utiliser, et quels plugins d'inventaire autoriser.

Ce detail est important pour expliquer le projet : Ansible n'est pas lance dans
le vide. Il a toujours besoin de trois choses :

```text
inventaire -> variables -> playbook
```

Dans ce projet, les variables communes viennent de
[`ansible/group_vars/all.yml`](../ansible/group_vars/all.yml). C'est la que l'on
retrouve par exemple les flags qui gardent `cloudflare-tunnel` et
`gitlab-runner` desactives par defaut.

### Comment `k3s-install` evite les surprises

Le role [`ansible/roles/k3s-install`](../ansible/roles/k3s-install/) installe le
cluster Kubernetes local. La decision importante est visible dans ses defaults :

```yaml
k3s_install_extra_args:
  - "--flannel-backend=none"
  - "--disable-network-policy"
  - "--disable-kube-proxy"
```

Cela veut dire : k3s demarre sans son reseau par defaut. Ce n'est pas une
optimisation gratuite ; c'est une preparation pour Cilium. On evite d'avoir
Flannel et Cilium qui essaient tous les deux de gerer le reseau des pods.

Le role commence aussi par des assertions. Dans
[`ansible/roles/k3s-install/tasks/main.yml`](../ansible/roles/k3s-install/tasks/main.yml),
il verifie que l'hote ressemble bien a la cible attendue : Linux, famille
Debian, systemd. C'est une barriere simple mais utile : si quelqu'un lance le
role sur une machine qui ne correspond pas, l'erreur arrive tot et clairement.

Ensuite le role ne reinstalle pas aveuglement k3s. Il observe d'abord l'etat :

```yaml
- name: Check whether k3s is already installed
  ansible.builtin.stat:
    path: /usr/local/bin/k3s
  register: k3s_binary
```

Puis il lit la version actuelle et le service systemd, calcule si les flags ont
derive, et produit une variable de decision : `k3s_needs_install`.

Le raisonnement est :

```text
k3s absent -> installer
mauvaise version -> installer
flags systemd differents -> reinstaller
force_reinstall=true -> reinstaller
sinon -> ne pas toucher
```

C'est exactement l'idempotence en pratique : relancer le role ne doit pas
modifier la machine si elle est deja conforme.

<p align="center">
  <img src="diagrams/concepts-s0-role-contract.svg" alt="Contrat technique d'un role Ansible" width="1050">
</p>

> Source editable :
> [`diagrams/concepts-s0-role-contract.drawio`](diagrams/concepts-s0-role-contract.drawio).

### Pourquoi il y a un handler

Le role `k3s-install` a aussi un handler dans
[`ansible/roles/k3s-install/handlers/main.yml`](../ansible/roles/k3s-install/handlers/main.yml).

```yaml
- name: Restart k3s
  ansible.builtin.service:
    name: k3s
    state: restarted
```

La task d'installation notifie ce handler uniquement quand elle change quelque
chose. Le handler ne tourne donc pas a chaque execution. Il sert a dire :
"si l'installation ou la configuration a vraiment change, alors redemarre k3s".

La nuance est importante :

```text
task = action dans le flux normal
handler = reaction declenchee par un changement
```

Ce pattern evite de redemarrer des services sans raison, tout en garantissant
qu'un changement reel est bien pris en compte.

### Comment le kubeconfig est rendu utilisable

k3s cree un kubeconfig systeme dans `/etc/rancher/k3s/k3s.yaml`. Ce fichier est
utile, mais il appartient au monde systeme. Le role le copie ensuite vers le
compte utilisateur cible :

```yaml
- name: Synchronize kubeconfig for target user
  ansible.builtin.copy:
    content: "{{ k3s_system_kubeconfig.content | b64decode }}"
    dest: "{{ k3s_user_kubeconfig_path }}"
    owner: "{{ k3s_kubeconfig_user }}"
    group: "{{ k3s_kubeconfig_group }}"
    mode: "0600"
```

Techniquement, cela permet d'utiliser `kubectl` sans `sudo`. Cote securite, le
mode `0600` est important : le kubeconfig donne un acces administrateur au
cluster local, donc il ne doit pas etre lisible par tout le monde.

### Comment Cilium prend le relais du reseau

Une fois k3s installe, le cluster n'est pas complet : on a l'API Kubernetes,
mais on a volontairement retire le CNI par defaut. C'est le role
[`ansible/roles/cilium-setup`](../ansible/roles/cilium-setup/) qui rend le
cluster vraiment utilisable.

Ses defaults expliquent plusieurs choix non triviaux :

```yaml
cilium_kube_proxy_replacement: true
cilium_k8s_service_host: "{{ ansible_facts['default_ipv4']['address'] }}"
cilium_devices: "{{ ansible_facts['default_ipv4']['interface'] }}"
cilium_operator_replicas: 1
```

Le mode `kubeProxyReplacement` signifie que Cilium remplace kube-proxy pour le
routage des Services Kubernetes. Comme k3s a ete demarre avec
`--disable-kube-proxy`, ce choix n'est pas optionnel : quelqu'un doit assurer le
routage des Services, et ici c'est Cilium.

Le `k8sServiceHost` est aussi important. Dans ce setup local, Cilium doit savoir
joindre directement l'API Kubernetes sur l'IP du noeud. C'est justement un des
points qui avait pose probleme quand l'ancien etat k3s pointait vers une
ancienne IP.

Enfin, `cilium_operator_replicas: 1` vient du fait que le lab est mono-noeud.
Deux replicas d'operator seraient plus proches d'un cluster multi-noeud, mais
ici ils peuvent rester Pending a cause des contraintes locales. On documente le
compromis au lieu de pretendre que le lab est une production.

<p align="center">
  <img src="diagrams/concepts-s0-k3s-cilium-lifecycle.svg" alt="Cycle k3s Cilium et kubeconfig" width="1050">
</p>

> Source editable :
> [`diagrams/concepts-s0-k3s-cilium-lifecycle.drawio`](diagrams/concepts-s0-k3s-cilium-lifecycle.drawio).

### Pourquoi le role touche a `ufw`

Le role contient cette task :

```yaml
- name: Allow the Cilium pod CIDR to reach the host through ufw
  community.general.ufw:
    rule: allow
    from_ip: "{{ cilium_pod_cidr }}"
    comment: "Cilium pod CIDR to host (k3s API, cilium agent, hubble-peer)"
```

Elle existe parce que, dans ce lab, certains flux pod -> hote sont legitimes :
API Kubernetes, agent Cilium, Hubble. Si `ufw` bloque tout trafic entrant, des
pods peuvent ne pas reussir a parler a l'IP du noeud, meme si le cluster semble
partiellement demarre.

Le point a savoir expliquer : ouvrir ce flux ne veut pas dire abandonner toute
isolation reseau. L'isolation fine entre workloads doit venir ensuite des
NetworkPolicies Cilium.

### Pourquoi CoreDNS peut etre redemarre

CoreDNS est le DNS interne de Kubernetes. Au boot, il peut etre programme avant
que Cilium soit completement pret. Le role detecte donc si CoreDNS n'est pas
Ready, puis le redemarre une fois le reseau en place.

Ce n'est pas un redemarrage systematique. La task est conditionnee :

```yaml
when:
  - cilium_runtime_validation_enabled | bool
  - "'True' not in cilium_coredns_initial.stdout"
```

C'est une bonne illustration de la logique "observer avant d'agir". On ne
corrige que si l'etat observe le justifie.

### Comment MiniStack sert le projet

[`ansible/roles/ministack-setup`](../ansible/roles/ministack-setup/) prepare un
petit environnement local qui expose une API compatible avec certains usages AWS
de test.

Le role fait trois choses :

1. il verifie que Docker et AWS CLI sont disponibles ;
2. il lance le container MiniStack ;
3. il ecrit un profil AWS CLI dedie.

Le controle interessant est le smoke test STS :

```bash
aws --profile "{{ ministack_aws_profile_name }}" \
  --endpoint-url "{{ ministack_effective_endpoint_url }}" \
  sts get-caller-identity
```

Ce test ne prouve pas qu'AWS reel fonctionne. Il prouve que le chemin local
profil AWS CLI -> endpoint MiniStack -> reponse compatible est coherent. Pour
un lab, c'est utile : on valide des mecanismes sans payer ni toucher une vraie
ressource cloud.

### Comment le runner GitLab est rendu optionnel

Le role [`ansible/roles/gitlab-runner`](../ansible/roles/gitlab-runner/) est
plus sensible, parce qu'il a besoin d'un token externe. C'est pour cela que
`bootstrap.yml` ne l'active que si `bootstrap_enable_gitlab_runner` vaut `true`.

Dans le role, l'enregistrement est aussi protege :

```yaml
- name: Assert token is present when registration is enabled
  ansible.builtin.assert:
    that:
      - gitlab_runner_token | length > 0
  when: gitlab_runner_manage_registration | bool
  no_log: true
```

Deux idees sont importantes ici :

- on ne versionne pas le token ;
- on masque les donnees sensibles dans les logs Ansible avec `no_log: true`.

En entretien, c'est un bon exemple pour montrer que l'automatisation ne veut pas
dire "mettre des secrets dans Git".

### Comment on prouve que les roles sont rejouables

Molecule sert a tester un role dans un environnement isole. Sur
[`ansible/roles/k3s-install/molecule/default/converge.yml`](../ansible/roles/k3s-install/molecule/default/converge.yml),
le scenario cree un utilisateur de test, puis applique le role.

Le fichier
[`ansible/roles/k3s-install/molecule/default/verify.yml`](../ansible/roles/k3s-install/molecule/default/verify.yml)
ne configure plus rien. Il observe :

- le service `k3s` est actif ;
- le service systemd contient les bons flags ;
- le kubeconfig utilisateur existe avec les bonnes permissions ;
- `kubectl` peut lister au moins un noeud.

La boucle mentale est :

```text
converge -> le role configure
idempotence -> le role rejoue sans changement inutile
verify -> on observe l'etat attendu
```

Ce n'est pas juste du test pour cocher une case. C'est ce qui permet de dire :
"je peux rejouer mon bootstrap apres une coupure, une correction ou une
evolution, et voir precisement ce qui change".

### Pourquoi les playbooks futurs ont `apply=false`

Le Sprint 0 a aussi cadre deux playbooks futurs :

- [`ansible/playbooks/runner-setup.yml`](../ansible/playbooks/runner-setup.yml)
- [`ansible/playbooks/rds-setup.yml`](../ansible/playbooks/rds-setup.yml)

Ils existent pour clarifier la frontiere Terraform / Ansible. Terraform creera
les ressources AWS ; Ansible configurera ce qui vit apres la creation :
runner, bases et users.

Le point cle est qu'ils sont inoffensifs par defaut :

```yaml
runner_setup_apply: false
rds_setup_apply: false
```

Cela permet de versionner l'interface attendue sans appeler AWS ou RDS trop
tot. Les playbooks documentent deja les inputs et les secrets attendus, mais
ils ne font rien tant que l'activation n'est pas explicite.

## S1-T1 - Comment la base GitOps commence

### Vue globale : Git, Argo CD, Kustomize et Kubernetes

Avant de rentrer dans les fichiers, il faut separer les responsabilites. Dans
un flux GitOps, plusieurs outils apparaissent cote a cote, mais ils ne font pas
le meme travail.

```mermaid
flowchart LR
  D[Developpeur ou CI] --> G[GitLab.com ou GitHub<br/>repo GitOps]
  G --> A[Argo CD<br/>controleur GitOps]
  A --> K[Kustomize<br/>rendu YAML]
  K --> API[API Kubernetes]
  API --> R[Namespaces et workloads]
```

Git et Argo CD ne font pas le meme travail. Git stocke des repositories, des
commits et des branches. Argo CD est un controleur Kubernetes : il lit un
repository Git, compare ce qu'il y trouve avec l'etat reel du cluster, puis
synchronise le cluster quand c'est autorise.

Le projet ne deploie plus de forge Git self-hosted dans le MVP. La relation
cible est donc :

```text
GitLab.com ou GitHub = la source de verite Git
Argo CD = le moteur qui reconcilie cette source avec Kubernetes
Kustomize = l'outil qui transforme les dossiers YAML en manifests finaux
Kubernetes = le systeme qui stocke et execute l'etat reel
```

Aujourd'hui, dans `S1-T1`, on ne deploie pas encore Argo CD. On prepare
seulement le contenu que GitOps devra lire : les dossiers, les namespaces et
les points d'entree Kustomize.

### Le probleme qu'on resout

Apres Sprint 0, on a un cluster local utilisable. La question devient :
"comment va-t-on decrire ce que Kubernetes doit contenir ?".

Une mauvaise reponse serait de lancer a la main des commandes `kubectl apply`
sans structure durable. Ca marcherait peut-etre une fois, mais on perdrait vite
la trace de l'intention.

La reponse du Sprint 1 est GitOps : l'etat desire vit dans Git, et Argo CD le
synchronisera plus tard.

### Ce que `S1-T1` met vraiment en place

Le repertoire [`../gitops/`](../gitops/) est volontairement simple :

```text
gitops/
  platform/
  apps/
  environments/
  argocd/
```

`platform/` contient ce qui appartient au cluster, pas a une application. En
`S1-T1`, cela se limite aux namespaces techniques :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
```

`environments/staging/` et `environments/prod/` contiennent ce qui depend d'un
environnement applicatif. Pour l'instant, chaque environnement cree seulement
son namespace :

```yaml
metadata:
  name: shopdemo-staging
  labels:
    shopdemo.io/environment: staging
```

Cette separation evite qu'un environnement staging transporte par accident des
ressources prod ou des ressources globales du cluster.

<p align="center">
  <img src="diagrams/s1-gitops-repo-structure.svg" alt="Structure GitOps du Sprint 1" width="1050">
</p>

> Source editable :
> [`diagrams/s1-gitops-repo-structure.drawio`](diagrams/s1-gitops-repo-structure.drawio).

### Le role exact de Kustomize

La vue globale de Kustomize est simple : il ne decide pas quoi deployer, il ne
parle pas a Git, et il ne surveille pas le cluster. Il prend un dossier en
entree et produit du YAML Kubernetes en sortie.

Dans chaque dossier deployable, il y a donc un `kustomization.yaml`. Ce fichier
est la table des matieres du dossier.

Exemple dans
[`gitops/platform/kustomization.yaml`](../gitops/platform/kustomization.yaml) :

```yaml
resources:
  - namespaces/base
```

Ce fichier ne cree rien par lui-meme. Il dit seulement a Kustomize :
"pour rendre ce dossier, inclus le dossier `namespaces/base`".

Kustomize suit alors le chemin et lit
[`gitops/platform/namespaces/base/kustomization.yaml`](../gitops/platform/namespaces/base/kustomization.yaml) :

```yaml
resources:
  - namespaces.yaml
```

Ce deuxieme fichier pointe enfin vers
[`gitops/platform/namespaces/base/namespaces.yaml`](../gitops/platform/namespaces/base/namespaces.yaml),
qui contient les vrais objets Kubernetes :

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    app.kubernetes.io/part-of: shopdemo-platform
    app.kubernetes.io/managed-by: gitops
    shopdemo.io/environment: platform
---
apiVersion: v1
kind: Namespace
metadata:
  name: gateway-system
  labels:
    app.kubernetes.io/part-of: shopdemo-platform
    app.kubernetes.io/managed-by: gitops
    shopdemo.io/environment: platform
```

La reponse concrete a "ou est-ce qu'on lui dit de creer les namespaces ?" est
donc : on ne le dit pas a Kustomize sous forme d'ordre special. On met des
objets Kubernetes `kind: Namespace` dans `namespaces.yaml`, puis on reference ce
fichier dans la chaine des `resources`.

Quand on lance :

```bash
kubectl kustomize gitops/platform
```

Kustomize lit le fichier `kustomization.yaml`, suit la liste `resources`, puis
sort un YAML final. Dans ce lot, ce YAML final contient les namespaces `argocd`
et `gateway-system`.

La nuance importante :

```text
kubectl kustomize = rendre le YAML
kubectl apply -k = rendre puis appliquer
Argo CD sync = rendre puis reconcilier depuis Git
```

Pour `S1-T1`, on utilise seulement le rendu. C'est ce qui permet de valider la
structure GitOps sans modifier le cluster.

Le meme principe existe pour les environnements applicatifs :

```text
gitops/environments/staging/kustomization.yaml
  -> namespace.yaml
  -> Namespace shopdemo-staging

gitops/environments/prod/kustomization.yaml
  -> namespace.yaml
  -> Namespace shopdemo-prod
```

Les labels donnent une information lisible et filtrable :

```yaml
app.kubernetes.io/part-of: shopdemo
app.kubernetes.io/managed-by: gitops
shopdemo.io/environment: staging
```

`argocd` existe parce que ce namespace accueille le control plane Argo CD,
installe depuis `S1-T2`. `gateway-system` existe parce que Gateway API, NGINX Gateway
Fabric et les composants d'entree/authentification doivent rester separes des
applications metier. `shopdemo-staging` et `shopdemo-prod` existent pour que les
workloads applicatifs aient des frontieres claires par environnement.

### Comment les validations prouvent le cadrage

Les validations de `S1-T1` ne cherchent pas a prouver qu'Argo CD marche,
puisqu'il n'est pas encore installe.

Elles prouvent plutot trois choses :

- Kustomize peut rendre chaque point d'entree ;
- les YAML respectent le style attendu ;
- les manifests rendus ressemblent a des objets Kubernetes valides.

Les commandes utiles sont :

```bash
kubectl kustomize gitops/platform
kubectl kustomize gitops/environments/staging
kubectl kustomize gitops/environments/prod
yamllint gitops
kubeconform -strict -ignore-missing-schemas <rendered-yaml>
```

C'est une validation adaptee au niveau du sprint. On ne simule pas une maturite
qui n'existe pas encore ; on prouve seulement le contrat du lot courant.

## S1-T2 - Comment Argo CD est installe et synchronise

### Le probleme qu'on resout

`S1-T1` a pose l'intention dans Git (namespaces, structure `gitops/`), mais
rien ne la lisait encore. Sans un controleur qui observe le repository, cette
intention reste juste du YAML inerte : personne ne compare, personne ne
reconcilie. `S1-T2` installe ce controleur : Argo CD.

### Ce que `S1-T2` met vraiment en place

Trois objets concrets, dans [`../gitops/argocd/`](../gitops/argocd/) :

```text
gitops/argocd/
  install.yaml                        # Argo CD lui-meme (CRD, controllers, RBAC)
  bootstrap-application-platform.yaml # la premiere Application
  README.md
```

`install.yaml` est le manifest officiel du projet Argo CD, telecharge depuis
un tag versionne (`v3.5.2`), pas depuis l'alias flottant `stable` :

```bash
curl -sL -o gitops/argocd/install.yaml \
  https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/install.yaml
```

Pourquoi un tag et pas `stable` : `stable` peut pointer vers une version
differente demain, ce qui rendrait l'installation non reproductible d'une
session a l'autre. Un tag fige la version que ce depot documente reellement.

Premiere subtilite technique : ce manifest ne s'installe pas avec un simple
`kubectl apply`. Le CRD `applicationsets.argoproj.io` est trop volumineux pour
l'annotation `kubectl.kubernetes.io/last-applied-configuration` que le
client-side apply essaie d'y ecrire (limite de 262144 octets). Il faut
utiliser l'apply cote serveur, qui ne pose pas cette annotation :

```bash
kubectl apply -n argocd -f gitops/argocd/install.yaml \
  --server-side --force-conflicts
```

Une fois Argo CD vivant (7 pods dans le namespace `argocd`), il lui faut une
premiere `Application` : l'objet qui lui dit *quel* repo Git lire et *quel*
chemin y surveiller.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://gitlab.com/ClementV78/shopdemo.git
    targetRevision: main
    path: gitops/platform
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

`prune: true` supprime du cluster ce qui disparait de Git. `selfHeal: true`
annule automatiquement toute derive manuelle (un `kubectl edit` fait a la main
sur une ressource geree serait ecrase au prochain cycle). C'est volontaire :
le but de GitOps est que Git reste la seule source d'ecriture durable.

### Le repo prive et le credential Git

Le repo `ClementV78/shopdemo` est prive sur GitLab. Argo CD a donc besoin d'un
identifiant pour cloner. Ce credential ne vit jamais dans Git : il est cree
directement comme `Secret` Kubernetes, avec un token GitLab dedie et minimal
(role `Reporter`, scope `read_repository` uniquement, pas le token plus
privilegie deja utilise par la CI).

Deuxieme subtilite technique, facile a oublier : Argo CD ne reconnait un
`Secret` comme credential de repository que s'il porte un label precis. Sans
ce label, le secret existe mais Argo CD l'ignore silencieusement :

```bash
kubectl label secret argocd-repo-shopdemo -n argocd \
  argocd.argoproj.io/secret-type=repository
```

### Ce qui peut casser autour d'Argo CD sans que ce soit Argo CD

Le premier essai de synchronisation de `S1-T2` a echoue non pas a cause d'Argo
CD, mais a cause d'une panne d'egress reseau du cluster (une regression
Cilium heritee du reset du 2026-09-05) : aucun pod ne pouvait sortir vers
Internet, donc Argo CD ne pouvait pas cloner le repo. La lecon a retenir : un
`Sync Status: Unknown` avec une erreur `dial tcp: lookup ... server
misbehaving` n'est pas forcement un probleme de configuration GitOps, ca peut
etre la couche reseau en dessous. Diagnostic complet, boucle
hypothese/commande/observation et schema du blocage :
[`evidence/sprint-1/s1-t2-cilium-egress-blocker.md`](evidence/sprint-1/s1-t2-cilium-egress-blocker.md).

### Comment les validations prouvent que ca marche

```bash
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get application platform -n argocd \
  -o jsonpath='{.status.sync.status}{" / "}{.status.health.status}{"\n"}'
```

La preuve attendue est `Synced / Healthy`, sans qu'aucun secret n'ait ete
committe dans Git a aucun moment de ce lot.

## S1-T3 - Comment les namespaces applicatifs et l'isolation arrivent

### Le probleme qu'on resout

`S1-T2` a branche Argo CD sur `gitops/platform`. Mais `gitops/environments/`
existait depuis `S1-T1` et personne ne le lisait. Les namespaces
`shopdemo-staging` et `shopdemo-prod` etaient decrits dans Git sans jamais
atteindre le cluster.

### Deux Applications de plus, volontairement manuelles

[`../gitops/argocd/application-staging.yaml`](../gitops/argocd/application-staging.yaml)
et [`../gitops/argocd/application-prod.yaml`](../gitops/argocd/application-prod.yaml)
prennent enfin en charge `gitops/environments/`. Les deux demarrent en
synchronisation **manuelle**, ce qui merite une explication.

Une `Application` automatisee applique immediatement ce qu'elle trouve. Or ces
Applications posent des `NetworkPolicy`. Une policy trop large appliquee sans
verification peut couper un chemin reseau dont Argo CD lui meme depend. La
porte manuelle sert donc a observer l'ecart avant de le fermer : les policies
sont poussees sur GitLab, l'`Application` passe `OutOfSync`, et
`kubectl get networkpolicies` reste vide tant que la synchronisation n'est pas
declenchee.

### Ce que font les deux policies

```yaml
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}        # tous les pods du namespace
  policyTypes:
    - Ingress            # aucune regle ingress -> tout est refuse
---
kind: NetworkPolicy
metadata:
  name: allow-ingress-same-namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}   # seulement les pods du meme namespace
```

### Le mecanisme reel, et une redondance assumee

L'API `NetworkPolicy` ne sait pas refuser. Il n'existe aucune regle `deny` :
on ne peut qu'autoriser. Le refus est un **effet de bord de la selection**.

La regle exacte est celle-ci. Un pod devient *isole* en entree des qu'au moins
une `NetworkPolicy` le selectionne avec `Ingress` dans ses `policyTypes`. A
partir de la, seule l'union des regles `ingress` des policies qui le
selectionnent est autorisee, et tout le reste tombe. Un pod que personne ne
selectionne reste, lui, entierement ouvert.

Une consequence merite d'etre vue tout de suite, parce qu'elle surprend :
`allow-ingress-same-namespace` **suffirait a elle seule**. Elle selectionne
tous les pods avec `policyTypes: [Ingress]`, donc elle isole, puis elle rouvre
le chemin intra-namespace. `default-deny-ingress` ajoute a l'union un ensemble
de regles vide, ce qui ne change rien au resultat.

Alors pourquoi la garder ? Pas pour le trafic d'aujourd'hui, mais contre une
modification de demain. Si quelqu'un restreint plus tard
`allow-ingress-same-namespace` a un sous-ensemble de pods, par exemple
`podSelector: {matchLabels: {app: web}}` pour affiner les autorisations, les
pods sans ce label ne sont plus selectionnes par aucune policy. Ils cessent
d'etre isoles et redeviennent joignables depuis n'importe quel namespace. Un
durcissement apparent aurait ouvert un trou.

`default-deny-ingress`, qui garde `podSelector: {}`, reste alors la couverture
de tous les pods. Le filet de securite est ainsi decouple du cycle de vie de la
regle d'autorisation. C'est aussi la convention que cherchent les controles
d'audit et les policies Kyverno, qui rendent la posture d'un namespace lisible
sans avoir a raisonner sur l'union des regles.

La redondance est donc deliberee, et c'est une redondance de robustesse, pas un
mecanisme necessaire. La distinction compte : croire que le refus vient de
l'objet nomme `default-deny` amene a mal raisonner des qu'on modifie l'autre.

Point important souvent mal compris : `policyTypes: [Ingress]` ne touche pas
l'egress. Un pod continue donc de joindre l'exterieur, ce qui a ete verifie
apres application en resolvant `gitlab.com` depuis `shopdemo-staging`.

Pour s'en convaincre sans toucher aux namespaces geres par Argo CD, il suffit
de creer un namespace jetable ne portant que la policy d'autorisation, et de
constater qu'un appel venant d'ailleurs echoue quand meme :

```bash
kubectl create namespace np-test
kubectl -n np-test run web --image=nginxinc/nginx-unprivileged:1.27-alpine --port=8080
kubectl -n np-test expose pod web --port=8080
kubectl -n np-test apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-same-ns}
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress: [{from: [{podSelector: {}}]}]
EOF
kubectl -n default run probe --rm -it --image=curlimages/curl --restart=Never -- \
  curl -m 5 -s -o /dev/null -w '%{http_code}\n' http://web.np-test:8080
kubectl delete namespace np-test
```

Le namespace `argocd` reste volontairement hors perimetre. Lui appliquer un
refus par defaut sans avoir d'abord cartographie ses flux reviendrait a
risquer de couper l'outil qui applique les policies.
[`ADR-008`](adr/ADR-008-standard-networkpolicy-by-default.md) acte par ailleurs
l'usage de la `NetworkPolicy` standard plutot que de la `CiliumNetworkPolicy`,
gardee pour les cas que le standard ne couvre pas.

## S1-T4 - Comment une application est decrite une fois

### Le probleme qu'on resout

Les namespaces existent et sont isoles, mais rien ne tourne dedans. Il faut un
workload reel pour eprouver les policies, et une facon de le decrire qui ne
duplique pas les manifests entre staging et prod.

### Base et overlays

```text
gitops/apps/smoke/
  base/                  # la description commune
    deployment.yaml
    service.yaml
    serviceaccount.yaml
    poddisruptionbudget.yaml
    kustomization.yaml
  overlays/staging/      # ce qui change pour staging
  overlays/prod/         # ce qui change pour prod
```

L'overlay ne recopie pas la base, il la reference et la modifie. C'est le
principe de Kustomize : une seule verite, des variations declarees.

### Les conventions posees, et leur raison

```yaml
image: nginxinc/nginx-unprivileged:1.27-alpine@sha256:65e3e85d...
```

L'image est epinglee par **digest**, pas par tag. Un tag comme `1.27-alpine`
peut pointer vers un contenu different demain ; un digest designe un contenu
exact et immuable. Sans cela, deux synchronisations du meme commit Git
pourraient deployer deux images differentes, ce qui ruine la promesse GitOps.

```yaml
automountServiceAccountToken: false
securityContext:
  runAsNonRoot: true
  runAsUser: 101
containers:
  - securityContext:
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
```

Chaque ligne ferme une porte. Le token de `ServiceAccount` n'est pas monte,
donc un pod compromis ne peut pas parler a l'API Kubernetes. L'execution est
non-root avec un uid explicite. La racine est en lecture seule. Toutes les
capabilities Linux sont retirees.

```yaml
replicas: 2
strategy:
  rollingUpdate:
    maxUnavailable: 0
```

Deux repliques, et non une. Le `PodDisruptionBudget` fixe `minAvailable: 1` :
sur une replique unique, il interdirait tout drain de noeud, donc toute
maintenance. Un PDB mal dimensionne bloque les operations qu'il est cense
proteger.

`maxUnavailable: 0` interdit a Kubernetes de retirer un pod sain avant qu'un
nouveau soit pret. Ce reglage aura une consequence inattendue en `S1-T7`.

## S1-T5 - Comment les Applications cessent d'etre ecrites a la main

### Le probleme qu'on resout

A ce stade, ajouter un service imposerait d'ecrire une `Application` Argo CD de
plus. Avec quatre microservices Go a venir et deux environnements, cela fait
huit objets a maintenir a la main, qui divergeront.

### Le generateur

[`../gitops/argocd/applicationset-staging.yaml`](../gitops/argocd/applicationset-staging.yaml)
remplace la declaration par une regle :

```yaml
generators:
  - git:
      repoURL: https://gitlab.com/ClementV78/shopdemo.git
      revision: main
      directories:
        - path: gitops/apps/*/overlays/staging
template:
  metadata:
    name: 'staging-{{index .path.segments 2}}'
```

Argo CD scanne le depot, trouve chaque repertoire correspondant au motif, et
fabrique une `Application` par resultat. Le chemin
`gitops/apps/smoke/overlays/staging` se decoupe en segments, et l'index `2`
porte le nom de l'application. Ajouter un service revient desormais a creer un
repertoire.

### Ce que le transfert de propriete a montre

L'`Application` `staging-smoke` generee reprend un `Deployment` qui existait
deja, cree par l'ancienne `Application` ecrite a la main. Argo CD identifie ce
qu'il gere par l'annotation `argocd.argoproj.io/tracking-id`. Le transfert
consiste donc a changer un proprietaire, pas a recreer une ressource : l'age du
`Deployment` est reste inchange, preuve qu'aucune interruption n'a eu lieu.

Le piege a connaitre : la suppression d'une `Application` generee detruit ses
ressources par defaut. C'est voulu pour une mise hors service, mais cela
transforme une erreur de motif en suppression reelle. Une `Application`
supprimee a la main a d'ailleurs ete recreee par l'`ApplicationSet` en moins de
dix secondes, ce qui montre qui possede vraiment le cycle de vie.

## S1-T6 - Comment la production se separe de staging

### Le probleme qu'on resout

Staging et prod lisaient tous les deux `main`. Un merge partait donc
simultanement dans les deux environnements : il n'y avait pas de frontiere, ce
qui rend le mot production trompeur.

### La contrainte semver

```yaml
source:
  targetRevision: 'v*'
```

Cette ligne fait tout le travail. Argo CD traite `v*` comme une **contrainte
semver**, et une contrainte semver ne s'evalue que sur les tags, jamais sur les
branches. Prod suit donc le tag le plus recent qui correspond, et un merge dans
`main` ne le concerne pas.

Le generateur prod scanne lui aussi le tag et non la branche :

```yaml
generators:
  - git:
      revision: 'v*'
      directories:
        - path: gitops/apps/*/overlays/prod
```

Scanner `main` creerait une `Application` des le merge, qui echouerait ensuite a
trouver son chemin dans un tag anterieur a sa creation.

### Ce qui a ete prouve

La frontiere a ete verifiee dans les deux sens : un merge dans `main` laisse
prod `Synced` sur l'ancien tag, sans meme signaler d'ecart, et un tag pose est
repris automatiquement en 150 secondes sans aucune intervention. Ce delai vient
de l'absence de webhook entre GitLab et Argo CD, qui interroge le depot
periodiquement.

Un premier essai a ete ecarte parce qu'un rafraichissement force coincidait
avec la reprise automatique : le resultat n'etait pas attribuable. Refaire une
mesure propre plutot que garder un resultat ambigu fait partie de la methode.

[`ADR-009`](adr/ADR-009-promotion-par-chemin-plutot-que-par-branche.md) acte ce
modele et ecarte les branches d'environnement prevues au plan initial.

## S1-T7 - Comment on revient en arriere

### Le probleme qu'on resout

Une procedure de rollback ecrite mais jamais executee n'est pas une procedure,
c'est une hypothese. `S1-T7` l'a donc executee sur un incident provoque.

### L'exercice

Une release volontairement defectueuse, portant un digest d'image inexistant, a
ete promue en production par un tag. La correction a consiste a poser un tag
superieur pointant sur un commit anterieur, sain. Le retour a `Healthy` a pris
72 secondes.

Poser un tag superieur plutot que supprimer le mauvais tag est deliberé :
l'historique reste lisible, et la contrainte semver retient de toute facon le
plus recent.

### Le resultat inattendu

Le service a repondu pendant tout l'incident. Le `maxUnavailable: 0` pose en
`S1-T4` a empeche Kubernetes de retirer un pod sain avant qu'un nouveau soit
pret. Une mauvaise release a donc produit un **deploiement bloque**, pas une
panne.

C'est une bonne nouvelle et un piege. Le signal a reconnaitre n'est pas une
erreur utilisateur, puisqu'il n'y en a pas : c'est Argo CD affichant
`Progressing` et le `Deployment` montrant moins de pods a jour que de repliques.
Un incident silencieux se detecte par la supervision, pas par les plaintes.

Le guide qui en est issu vit dans
[`exploitation-gitops.md`](exploitation-gitops.md).

## S2-T1 - Comment l'infrastructure AWS commence

### Le probleme qu'on resout

Le Sprint 2 est le premier a couter de l'argent et a creer des ressources
difficiles a defaire. Commencer par un `terraform apply` serait la mauvaise
facon d'ouvrir un tel sprint.

`S2-T1` reprend donc exactement la logique de `S1-T1` : poser la structure et
les conventions, tout valider, et ne creer strictement rien.

### Ce qui existe apres la tache

```text
terraform/
  bootstrap/   state permanent : Organization, SCPs, Identity Center, backend, OIDC
  modules/     modules internes, encore vides
  envs/        state ephemere, volontairement vide jusqu'au Sprint 3
```

### Les tags passent par le provider

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

`default_tags` applique les cinq tags obligatoires a toutes les ressources
supportees, sans les repeter une seule fois dans le code. La regle AWS Config
`required-tags` prevue en `S2-T6` verifiera ces memes cles : la conformite est
donc obtenue par construction plutot que par discipline.

### Une validation qui refuse une region

```hcl
variable "aws_region" {
  type    = string
  default = "eu-west-1"

  validation {
    condition     = startswith(var.aws_region, "eu-")
    error_message = "La region doit etre europeenne."
  }
}
```

Ce garde-fou double la SCP `deny-regions-outside-eu` a venir, mais du cote du
code. La difference compte : l'erreur apparait au `plan`, avec un message
lisible, au lieu d'un refus AWS au `apply`.

### Le fichier qu'il faut committer malgre son nom

Le `.gitignore` ignore tout ce qui touche au state, puis fait une exception :

```gitignore
*.tfstate
*.tfvars
**/.terraform/*
!.terraform.lock.hcl
```

`.terraform.lock.hcl` **doit** entrer dans Git. Il fige les empreintes
cryptographiques des providers, ce qui garantit que la CI installera exactement
les memes binaires que le poste local. Sans lui, le meme code pourrait produire
deux plans differents selon la machine.

### Ce qui vient ensuite, et pourquoi c'est contre-intuitif

Le backend n'est volontairement pas declare. Il ne peut pas l'etre : le bucket
S3 qui heberge le state n'existe pas encore, et il sera cree par Terraform lui
meme. Le state vit donc d'abord en local, cree le bucket, puis migre dedans.

<p align="center">
  <img src="diagrams/s2-bootstrap-state-sequence.svg" alt="Amorcage du state bootstrap" width="720">
</p>

> Rendu interactif :
> [`diagrams/s2-bootstrap-state-sequence.html`](diagrams/s2-bootstrap-state-sequence.html).

Le state local est un artefact d'amorcage, jamais une cible. Il est supprime
apres migration, et le `.gitignore` a ete pose avant qu'il existe, ce qui est
l'ordre correct.

## Ce qu'il faut savoir raconter en entretien

Le discours court :

> J'ai commence par automatiser mon lab local avec Ansible. Le playbook
> principal orchestre des roles specialises. Les roles observent l'etat avant
> d'agir, utilisent des handlers quand un service doit reagir a un changement,
> et sont testes avec Molecule pour verifier converge, idempotence et etat
> final. Ensuite, j'ai introduit une structure GitOps : Git porte l'etat desire,
> Kustomize rend les manifests, et Argo CD synchronise le cluster depuis un
> repo GitLab prive.

Les points techniques a maitriser :

- pourquoi k3s est installe sans Flannel, kube-proxy et NetworkPolicy native ;
- pourquoi Cilium doit ensuite etre installe en replacement mode ;
- pourquoi `ufw` peut bloquer des flux pod -> hote dans un lab local ;
- pourquoi les secrets ne sont pas versionnes et les roles sensibles sont
  optionnels ;
- pourquoi Molecule ne remplace pas tous les tests runtime, mais prouve
  l'idempotence d'un role ;
- pourquoi `kubectl kustomize` est une validation sans effet de bord ;
- pourquoi `platform/`, `apps/` et `environments/` sont separes dans GitOps.

## Ou aller ensuite

Pour approfondir :

- [`ansible-structure.md`](ansible-structure.md) pour la structure Ansible ;
- [`cours-accelere-ansible.md`](cours-accelere-ansible.md) pour les notions
  Ansible de base ;
- [`concepts-sprint-0.md`](concepts-sprint-0.md) pour les concepts Sprint 0 ;
- [`gitops-structure.md`](gitops-structure.md) pour la structure GitOps ;
- [`concepts-sprint-1.md`](concepts-sprint-1.md) pour les concepts GitOps ;
- [`evidence/sprint-1/recit-s1-t2.md`](evidence/sprint-1/recit-s1-t2.md) pour le recit narratif de `S1-T2`, avec
  schemas commentes et l'histoire de l'incident reseau ;
- [`exploitation-gitops.md`](exploitation-gitops.md) pour l'usage, le rollback
  et le depannage GitOps ;
- [`promotion-par-tags.md`](promotion-par-tags.md) pour le modele de promotion ;
- [`../terraform/README.md`](../terraform/README.md) pour les conventions
  Terraform du Sprint 2 ;
- [`sprints/sprint-0-ansible.md`](sprints/sprint-0-ansible.md),
  [`sprints/sprint-1-gitops-local.md`](sprints/sprint-1-gitops-local.md) et
  [`sprints/sprint-2-landing-zone.md`](sprints/sprint-2-landing-zone.md) pour
  les preuves detaillees.
