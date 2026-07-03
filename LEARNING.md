# Journal de montee en competence

Ce fichier suit les competences pratiquees sur l'IDP Platform. Il ne doit contenir aucun secret, token, identifiant de compte reel ou autre donnee sensible.

## Niveaux

| Niveau | Critere |
|---|---|
| `Decouverte` | Notion expliquee ou observee, sans mise en pratique autonome. |
| `Guide` | Mise en pratique realisee avec des instructions detaillees. |
| `Autonome` | Tache comparable realisee sans solution pas a pas, puis validee. |
| `Maitrise` | Competence appliquee dans plusieurs contextes, avec capacite a expliquer les choix et diagnostiquer les erreurs. |

Les niveaux `Autonome` et `Maitrise` exigent une demonstration pratique. Une explication recue ne suffit pas.

## Progression

| Competence | Niveau | Preuve pratique | Difficultes ou notions a revoir | Prochain exercice |
|---|---|---|---|---|
| Structure Ansible du projet (`inventory`, `playbook`, `role`, `defaults`, `handlers`) | `Guide` | Creation et validation du squelette Ansible + role `k3s-install` | Bien distinguer le role de chaque fichier et quand utiliser un handler | Expliquer a voix haute le chemin `ansible.cfg -> inventory -> playbook -> role` |
| `become: true` et separation admin / usage | `Guide` | Installation reelle de `k3s` via Ansible avec taches systeme elevees | Savoir quand elever et quand rester en utilisateur normal | Revoir le role et identifier quelles taches peuvent redevenir non privilegiees |
| Kubeconfig systeme vs kubeconfig utilisateur | `Guide` | Synchronisation de `/etc/rancher/k3s/k3s.yaml` vers `/home/xclem/.kube/config` | Eviter la derive entre source de verite root et copie utilisateur | Expliquer pourquoi `kubectl` quotidien doit fonctionner sans `sudo` |
| Idempotence Ansible | `Guide` | Second passage de `ansible-playbook playbooks/k3s-install.yml` avec `changed=0` | Reperer les fausses causes de changement | Rendre un prochain role idempotent des la premiere implementation |
| `k3s`, CNI, Flannel vs Cilium | `Guide` | Installation locale de `k3s` sans Flannel et observation d'un noeud `NotReady` avant Cilium | Relier `NotReady` a l'absence de CNI sans conclure trop vite a une panne | Expliquer pourquoi on desactive Flannel avant d'installer Cilium |
| Molecule pour un role systemd/k3s | `Guide` | Scenario `molecule test` vert pour `k3s-install` avec `syntax`, `converge`, `idempotence` et `verify` | Bien separer les adaptations du scenario de test et la cible du role | Expliquer pourquoi `--snapshotter=native` est acceptable dans Molecule mais pas a imposer au role cible |
| Outils Python CLI via `pipx` | `Guide` | `ansible-core`, `molecule` et son plugin Docker installes via `pipx` | Distinguer un outil CLI isole d'une dependance Python de projet | Installer les prochains outils CLI Python du poste avec `pipx` par defaut |
| Diagnostic `DiskPressure` kubelet | `Guide` | Cascade diagnostiquee : `cilium-operator` `Pending` (taint disque) -> CRDs jamais enregistrees -> agent Cilium en `CrashLoopBackOff`, remontee jusqu'a la cause racine (`/` a 94%, seuil `imagefs.available<15%`) via `describe pod`, `logs --previous`, `du`, `find -size` | Distinguer le seuil `nodefs.available<10%` du seuil plus strict `imagefs.available<15%` quand les deux pointent vers le meme systeme de fichiers ; connaitre `--eviction-pressure-transition-period` (5 min par defaut) qui retarde la levee de la condition meme apres nettoyage | Reproduire seul la meme methode (hypothese -> commande -> observation -> interpretation) sur une autre pression de ressource (memoire ou PID) |
| Lecture d'un environnement partage avant nettoyage | `Guide` | Identification que le poste heberge des services personnels actifs (Vaultwarden, Immich, Nextcloud, AdGuard, Coolify, VMs `libvirt`) avant tout `docker prune`, distinction entre espace reellement reclamable et espace en usage actif | Toujours verifier `docker ps -a` et l'activite reelle avant un nettoyage, meme suggere par un outil | Etablir un reflexe systematique de verification d'impact avant toute commande de nettoyage sur un hote partage |
| Cilium sur k3s : kube-proxy replacement + pare-feu hote | `Guide` | Diagnostic d'un blocage ou tous les pods (`CoreDNS`, `hubble-relay`, `metrics-server`) restaient `Ready=False` : depuis leur netns (`nsenter -t <pid> -n`) ils joignaient la gateway Cilium et l'exterieur (`192.168.31.1`) mais pas la ClusterIP de l'API (`10.43.0.1:443`) ni meme l'IP du noeud (`192.168.31.106:6443`). `cilium bpf ct list` montrait `TCP OUT ... -> 192.168.31.106:6443` avec `Packets=0` : DNAT applique mais paquet jamais emis. Deux causes empilees : (1) Cilium en `kube-proxy-replacement: false` interceptait quand meme le trafic Service en eBPF sans terminer le routage (semi-remplacement) ; (2) cause racine decisive : `ufw` actif en politique deny laissait le trafic pod -> IP du noeud arriver sur la chaine INPUT et le DROP-ait. Correctif complet : `--disable-kube-proxy` (k3s) + `kubeProxyReplacement: true` avec `k8sServiceHost`/`k8sServicePort` (Cilium) + regle `ufw allow from 10.42.0.0/16` ; confirmation par `nc` depuis le netns (timeout avant, `succeeded` apres la regle) | En direct routing, le trafic pod -> Service ClusterIP se termine sur l'IP locale du noeud et traverse donc le pare-feu HOTE (INPUT), pas seulement FORWARD : un `ufw` deny invisible casse tout le plan de controle interne. Toujours tester la connectivite reelle depuis le netns du pod, pas seulement `cilium status` (qui affichait `OK`). Sans kube-proxy, `k8sServiceHost` est obligatoire (amorcage : joindre l'API avant que le routage des Services existe) | Refaire le raisonnement netns par netns sur un autre symptome reseau, savoir lire une entree de `cilium bpf ct list`, et verifier le pare-feu hote (INPUT/FORWARD) avant de conclure a un bug CNI |
| Idempotence d'un flag de service systemd via Ansible | `Guide` | `k3s-install` ne se reinstallait que sur changement de version ; l'ajout de `--disable-kube-proxy` aux `extra_args` ne declenchait donc rien. Ajout d'une detection de derive : lecture de l'unite `k3s.service`, comparaison des flags desires avec ceux reellement actifs, et reinstallation si l'un manque | Un role idempotent doit reagir a l'intention declaree (les flags voulus), pas seulement a la version installee ; sinon un changement de configuration reste silencieusement sans effet | Generaliser ce reflexe : tout parametre injecte dans un service doit avoir une verification de derive correspondante |

## Questions De Comprehension

| Date | Sujet | Question | Resultat | Point a reprendre |
|---|---|---|---|---|
| 2026-06-13 | Docker / validation | Pourquoi `docker --version` seul ne suffit-il pas ? | A revoir | Distinguer presence du binaire, daemon actif et droits utilisateur |
| 2026-06-13 | Ansible / configuration | Pourquoi `config file = None` etait normal au debut ? | Compris | Aucun |
| 2026-06-13 | Kubernetes / kubeconfig | Pourquoi `k3s` installe et `kubectl` pointant ailleurs peuvent coexister ? | Compris | Aucun |
| 2026-06-13 | Kubeconfig / usages | Pourquoi garder source root + copie utilisateur ? | Compris | Aucun |
| 2026-06-14 | Molecule / conteneur | Pourquoi le test Docker avait-il besoin de `--snapshotter=native` ? | Compris | Aucun |

## Prochains Objectifs

- Consolider `Cilium` comme prochain concept majeur du Sprint 0.
- Revoir les bases Kubernetes minimales : noeud, pod, CNI, kubeconfig, service.
- Etre capable d'expliquer le role `k3s-install` et son scenario Molecule de
  bout en bout sans support.
- Utiliser `pipx` par defaut pour les outils CLI Python du poste, et reserver
  `pip` aux environnements virtuels de projet quand c'est justifie.

## Regles De Mise A Jour

- Mettre a jour ce journal apres une activite d'apprentissage significative, pas apres chaque modification mineure.
- Lier chaque progression a une preuve concrete : commande executee, code ecrit, diagnostic mene, test interprete ou decision expliquee.
- Ne pas augmenter un niveau sur la seule base de l'execution effectuee par l'agent.
- Noter les erreurs comme occasions d'apprentissage, avec leur cause racine et la methode de diagnostic.
- Conserver des entrees concises et supprimer les objectifs devenus obsoletes.
