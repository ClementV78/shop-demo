# IDP Platform — Internal Developer Platform

> Projet personnel de montée en compétences DevOps/Cloud Architecture.  
> Une plateforme de déploiement interne complète, construite autour d'une application e-commerce de démonstration, auto-hébergée sur serveur Ubuntu local avec une architecture cible AWS multi-comptes.

---

## Contexte fonctionnel

La plateforme héberge **ShopDemo**, une application e-commerce minimaliste servant de fil conducteur technique. L'application est volontairement simple côté métier — l'objectif est de justifier naturellement chaque choix d'architecture.

### Ce que fait ShopDemo

Un utilisateur peut s'inscrire, parcourir un catalogue de produits, ajouter des articles à son panier, passer une commande et effectuer un paiement simulé.

<p align="center"><img src="docs/diagrams/flux-achat-paiement-drawio.svg" alt="Flux achat et paiement" width="1350"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/flux-achat-paiement.html`](docs/diagrams/flux-achat-paiement.html) (version archify — thème clair/sombre, export PNG/SVG). Couvre le chemin synchrone navigation → commande → paiement et le chemin webhook async (API Gateway AWS → Lambda → SNS).

> **Pattern fan-out** : SNS publie vers deux queues SQS indépendantes. Chaque consumer reçoit sa propre copie du message — delivery indépendante, DLQ distincte par queue.

> **Deux chemins paiement distincts** : le chemin synchrone (`/api/paiement` → service Go) retourne immédiatement succès au client. Le chemin asynchrone (provider externe → API Gateway → Lambda → SNS) traite la confirmation en arrière-plan. Lambda est utilisé uniquement là où c'est son use case naturel : un webhook event-driven sans trafic continu.

Les endpoints sont documentés et testables via une **collection Bruno** (alternative open-source à Postman).

### Stack applicative

| Composant | Techno | Rôle |
|---|---|---|
| `frontend` | HTML + Pico.css (statique) | Login, catalogue, panier, confirmation |
| `service-catalogue` | Go (EKS) | CRUD produits |
| `service-panier` | Go (EKS) | Gestion panier par utilisateur |
| `service-commande` | Go (EKS) | Création commande, publication event SNS |
| `service-paiement` | Go (EKS) | Paiement simulé synchrone, retourne succès |
| `lambda-webhook-paiement` | Lambda (Go) | Reçoit callback provider, publie sur SNS |
| `service-stock` | Go (EKS) | Consomme SQS queue-stock, décrémente stock |
| `service-notification` | Go (EKS) | Consomme SQS queue-notification, log confirmation |

### Pourquoi ce contexte justifie chaque brique AWS

- **Cognito** — auth utilisateurs avec JWT + Hosted UI, comble une lacune identifiée en entretien
- **Gateway API NGINX** — frontière d'auth unique pour les services Go : un `jwt-authorizer` central (ExternalAuth) valide le JWT Cognito avant routage vers les pods (détail mécanisme en Sprint 3)
- **API Gateway AWS** — expose le webhook `/webhook/paiement` au provider externe, authentifié par API Key + validation signature HMAC. Périmètre distinct du cluster EKS
- **RDS PostgreSQL** — catalogue, panier, commandes, stock
- **SNS + SQS** — deux topics fan-out : `commande-créée` et `paiement-confirmé`, chacun vers 2 queues SQS avec DLQ
- **Lambda** — `lambda-webhook-paiement` : event-driven, pas de trafic continu, use case naturel serverless
- **S3** — assets frontend statiques + images produits
- **CloudFront** — sert les assets S3 et proxifie les appels API vers l'ALB
- **WAF** — protection couche 7 attachée à CloudFront
- **VPC Endpoints** — trafic AWS-to-AWS privé (ECR, SQS, Secrets Manager, S3, STS), réduit le volume traversant le NAT Gateway sans l'éliminer (cf. note NAT ci-dessous)

---

## Objectif DevOps

Ce projet couvre de A à Z les compétences attendues sur les missions DevOps/Cloud Architecture senior :

- **Landing Zone AWS** — Organizations, SCPs, IAM Identity Center, multi-compte
- **Kubernetes (k3s / EKS)** — Cilium comme CNI (chaining mode sur EKS), Gateway API, GitOps avec Argo CD multi-environnements
- **Terraform modules custom** — modules internes versionnés et opinionated
- **Ansible** — provisioning reproductible du serveur local avec tests Molecule, hardening CIS des nodes
- **Pipeline CI/CD** — GitLab Components réutilisables, GitOps bout en bout, digest pinning des images, OIDC auth vers AWS
- **Observabilité** — Prometheus + Loki + Grafana (stack PLG), Kubecost pour cost allocation EKS
- **DevSecOps** — shift-left : pre-commit, scan CI (Trivy + OWASP + GitLeaks), admission control Kyverno, gestion des secrets, threat model OWASP
- **FinOps** — session destroy, Spot + Graviton, VPC Endpoints, Cost Anomaly Detection

Toute l'infrastructure est 100% IaC : détruite et recréée à la demande via `terraform destroy` / `terraform apply` pour maîtriser les coûts AWS.

---

## Exigences non fonctionnelles cibles

| Dimension | Cible |
|---|---|
| Criticité | Lab / démonstrateur technique, pas production commerciale |
| Disponibilité | Haute disponibilité intra-région pour démontrer les patterns Multi-AZ (RDS, EKS nodes 3 AZs) |
| RTO | À définir par scénario ; cible indicative : restauration manuelle < 4h |
| RPO | RDS backup automatique + PITR ; cible indicative : < 24h, ou point de restauration PITR selon configuration |
| Données sensibles | Aucune — données fictives uniquement (catalogue, comptes, commandes de démo) |
| Conformité | Aucune exigence réglementaire réelle (pas de SOC2/PCI/HIPAA) — contrôles AWS Config/Kyverno à visée pédagogique |
| Multi-région | Non — toutes les ressources en `eu-west-1`/`eu-west-3`/`eu-central-1` (cf. SCP `deny-regions-outside-eu`) |
| Budget | ~115-185$ total projet, `terraform destroy` systématique hors sessions |

Ces cibles cadrent les choix d'architecture documentés plus bas : l'absence de multi-région, de WAF custom avancé, ou de chiffrement renforcé au-delà du standard AWS (KMS) sont des conséquences directes de ce niveau de criticité — pas des oublis.

---

## Stratégie de coûts AWS

<p align="center"><img src="docs/diagrams/couts-aws.svg" alt="Comptes AWS" width="850"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/couts-aws.html`](docs/diagrams/couts-aws.html) (version archify — export PNG/SVG).

| Phase | Ressources actives | Coût estimé | Stratégie |
|---|---|---|---|
| Sprints 0-1 | Serveur Ubuntu local uniquement | 0$ | Tout en local |
| Sprint 2 | Landing Zone (CloudTrail + Config minimal + S3) | ~5$/mois | Permanent — GuardDuty et Config CIS complet désactivés hors sessions |
| Sprints 3-6 | EKS + VPC + RDS + SQS (sessions) | ~0.75-1$/h | `terraform destroy` après chaque session, nodes Spot + Graviton |
| **Total projet** | | **~115-185$** | |

> **Landing Zone à 5$/mois** : 1 seul CloudTrail multi-région dans le management account (~2$) + AWS Config limité aux règles `required-tags` et `cloudtrail-enabled` (~2$) + S3 logs (<1$). GuardDuty (~4$/mois pour 4 comptes) et les règles CIS Config complètes sont **désactivés par défaut** et réactivés via `terraform apply -target` uniquement pendant les sessions Sprint 3+ — un flag `enable_full_posture = true/false` dans `aws-baseline` bascule entre les deux modes.
>
> ⚠️ **Ce mode dégradé est un compromis FinOps pour un projet personnel, pas un pattern recommandé pour la production.** Hors session, la capacité de détection de compromission (GuardDuty) et la couverture de conformité (Config CIS) sont réduites sur les comptes staging/prod/sandbox. En production, GuardDuty doit rester actif en permanence au minimum sur les comptes `management`, `audit` et `prod` — la désactivation n'est défendable que parce qu'aucune donnée réelle ni charge de production ne transite par ces comptes entre les sessions.

### Décomposition du coût horaire en session

Le chiffre "~3-5$/session" mélange des coûts horaires et une durée de session implicite (~4-6h). Décomposition explicite :

| Ressource | Coût horaire | Notes |
|---|---|---|
| EKS control plane | $0.10/h | Fixe, indépendant du nombre de nodes — facturé dès `terraform apply` |
| 3× nodes Karpenter (Graviton Spot, m7g.medium) | ~$0.25/h | Spot ≈ 70% de réduction vs On-Demand |
| RDS PostgreSQL (t4g.micro, Multi-AZ) | ~$0.03/h | Graviton, instance la plus petite supportant Multi-AZ |
| VPC Interface Endpoints (×5 : ecr.api, ecr.dkr, sqs, secretsmanager, sts) | ~$0.05/h | $0.01/h par endpoint par AZ — ici 1 AZ pour limiter le coût session |
| NAT Gateway (1, pour trafic non-AWS) | ~$0.045/h | Voir note ci-dessous — conservé pour les dépendances hors AWS |
| ALB | ~$0.025/h | AWS Load Balancer Controller |
| CloudFront + WAF | ~$0.01/h | Trafic faible en session de démo |
| CloudWatch Logs (control plane EKS + app logs) | ~$0.02/h | Ingestion + storage court terme |
| **Total** | **~$0.53/h** | |

Avec marge (data transfer, snapshots, requêtes WAF) le coût réel observé tourne entre **$0.6 et $0.9/h**, soit ~$3-5 pour une session de 4-6h — cohérent avec le chiffre annoncé, mais explicite sur sa composition plutôt qu'un "~$0.45/h" optimiste qui omettait le control plane EKS et les Interface Endpoints.

### NAT Gateway vs VPC Endpoints — pourquoi les deux coexistent

Les VPC Endpoints couvrent le trafic **AWS-to-AWS** (ECR, SQS, Secrets Manager, S3, STS) sans passer par le NAT Gateway. Le NAT Gateway reste nécessaire pour le trafic **non-AWS** depuis les subnets privés : pull d'images publiques (Docker Hub, GHCR), dépendances Go (`proxy.golang.org`), accès à Gitea/GitLab.com pour les runners, validation de certificats (OCSP/CRL), et tout appel à des APIs externes (provider de paiement simulé inclus).

`enable_nat_gateway = true` par défaut dans le module `vpc`. Le passer à `false` est possible uniquement si toutes les dépendances ci-dessus sont éliminées ou redirigées (ex: mirror interne pour les images, runner sans accès Gitea externe) — non fait dans ce projet car le gain (~$0.045/h) ne justifie pas la perte de flexibilité pour un environnement de démo/apprentissage.

```bash
terraform apply -auto-approve   # début de session — plateforme up en ~20 min
# ... travail, tests, screenshots
terraform destroy -auto-approve # fin de session — facturation arrêtée
```

---

## Stack technique

| Couche | Outils |
|---|---|
| Frontend | HTML + Pico.css (statique, S3 + CloudFront) |
| Infra as Code | Terraform — **2 states séparés** (bootstrap permanent / workload éphémère) |
| Tests IaC local | MiniStack (remplace LocalStack Community — 60+ services AWS, MIT-licensé, supporte EKS + Cognito) |
| Provisioning | Ansible, Molecule — serveur local, EC2 runner, RDS, Gitea, hardening nodes EKS via `ansible-pull` |
| Container runtime | Docker, k3s |
| OS | Ubuntu 24.04 LTS (local + EC2 runner) · Amazon Linux 2023 (nodes EKS) |
| CNI | Cilium (eBPF) — chaining mode sur EKS, replacement mode sur k3s local |
| Ingress | Gateway API (NGINX Gateway Fabric) + jwt-authorizer (ExternalAuth, JWT Cognito) |
| GitOps | Argo CD, ApplicationSet |
| CI/CD | GitLab CI, GitLab Components, OIDC auth vers AWS |
| Registry | Gitea |
| Auth | AWS Cognito (JWT), Gateway API NGINX (validation), API Gateway AWS (webhook HMAC) |
| Messaging | AWS SNS + SQS (fan-out SNS → 2 queues par topic) |
| Serverless | AWS Lambda (webhook paiement) |
| CDN / Edge | AWS CloudFront |
| WAF | AWS WAF (règles managed + custom) |
| Load balancing | AWS ALB, AWS Load Balancer Controller |
| Base de données | AWS RDS PostgreSQL (Graviton t4g) |
| Observabilité métriques | Prometheus, Grafana, kube-state-metrics |
| Observabilité logs | Loki, Fluent Bit (DaemonSet) |
| Cost visibility EKS | Kubecost (namespace-level cost breakdown) |
| DevSecOps — pre-commit | detect-secrets, hadolint, tfsec |
| DevSecOps — CI | Trivy (image + IaC), OWASP Dependency-Check, GitLeaks |
| DevSecOps — runtime | Kyverno, Falco |
| DevSecOps — secrets | AWS Secrets Manager, External Secrets Operator |
| DevSecOps — threat model | OWASP Threat Dragon |
| Cloud posture | AWS Security Hub, GuardDuty, AWS Config |
| Cost management | AWS Budgets, Cost Explorer, Cost Anomaly Detection |
| Documentation API | Bruno (collection testable) |
| DNS / Exposition | Cloudflare Tunnel |

> **Note sur MiniStack** : LocalStack Community a passé ses services core en payant. MiniStack est le drop-in replacement MIT-licensé, zéro compte, zéro télémétrie — même port 4566. Il supporte EKS API, Cognito (JWTs valides), RDS (vrai Postgres), SQS, Secrets Manager. Pour Organizations et SCPs, un compte sandbox AWS reste la seule option fiable.

> **Cilium : replacement mode (local) vs chaining mode (EKS)** : en local, Cilium remplace entièrement le CNI puisqu'il n'y a aucune contrainte d'intégration cloud à respecter. Sur EKS, le VPC CNI d'AWS reste obligatoire pour l'attribution d'IP réelles depuis le VPC et l'intégration native (Security Groups par pod, peering, VPC Endpoints) : c'est ce qui permet à un pod d'être routable nativement dans l'infrastructure réseau AWS. Le VPC CNI seul ne sait toutefois pas appliquer de `NetworkPolicy` Kubernetes. Cilium est donc chaîné par-dessus : AWS reste responsable du *qui a quelle IP et comment ça route dans le VPC*, Cilium reste responsable du *qui a le droit de parler à qui*. Ce chaînage apporte l'enforcement `default-deny` + règles explicites (`platform/k8s/cilium/`) et l'observabilité Hubble, sans renoncer à l'intégration AWS native.

| Domaine | Local k3s | Cible EKS |
|---|---|---|
| CNI / routage pod-a-pod | **Remplacé par Cilium** : Flannel est désactivé, Cilium devient le vrai CNI du cluster local. | **Partagé** : l'AWS VPC CNI garde l'attribution d'IP et le routage natif dans le VPC ; Cilium est chaîné par-dessus. |
| Routage des Services (`kube-proxy`) | **Remplacé par Cilium** : `--disable-kube-proxy` côté `k3s`, `kubeProxyReplacement: true` côté Cilium. | **Non retenu comme axe principal à ce stade** : l'architecture documente surtout le chaining mode, pas un remplacement complet de `kube-proxy`. |
| `NetworkPolicy` | **Géré par Cilium** : `k3s` désactive le contrôleur natif pour laisser Cilium faire l'enforcement. | **Géré par Cilium** : c'est un des apports majeurs du chaînage sur EKS (`default-deny`, règles explicites, isolation east-west). |
| Observabilité réseau | **Oui** : Hubble est activé pour visualiser les flux et aider au diagnostic local. | **Oui** : Hubble reste l'outil prévu pour la visibilité réseau du cluster EKS. |
| Chiffrement nœud-à-nœud | **Non prévu actuellement** : aucun choix WireGuard/IPsec n'est documenté. | **Non prévu actuellement** : hors périmètre des sprints et de l'architecture cible actuelle. |
| Service mesh L7 | **Non** : le projet n'utilise pas les capacités service mesh de Cilium. | **Non** : le routage L7 repose sur Gateway API + NGINX + `jwt-authorizer`, pas sur un mesh Cilium. |

---

## Architecture cible

### Vue organisation AWS

<p align="center"><img src="docs/diagrams/organisation-aws.svg" alt="Organisation AWS" width="850"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/organisation-aws.html`](docs/diagrams/organisation-aws.html) (version archify — export PNG/SVG).

> **¹ SCP `deny-regions-outside-eu`** : s'applique uniquement aux services régionaux. Les services globaux (`iam`, `route53`, `cloudfront`, `sts`, `support`, `s3` control plane) sont explicitement exclus. Testé en compte sandbox avant déploiement sur prod OU.

### Vue Terraform — 2 states séparés (bootstrap vs workload)

<p align="center"><img src="docs/diagrams/terraform-states.svg" alt="2 states Terraform" width="850"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/terraform-states.html`](docs/diagrams/terraform-states.html) (version archify — export PNG/SVG).

> **Pourquoi 2 states** : le state `bootstrap` contient l'EC2 runner et le bucket S3 qui héberge le state `workload`. Si tout était dans un seul state, `terraform destroy` détruirait le runner en train d'exécuter le destroy — le serpent qui se mord la queue. Apply ET destroy du state `workload` tournent sur les **shared runners GitLab.com** (gratuits, hors du cycle de vie qu'ils gèrent) ; le **EC2 runner bootstrap** prend en charge les jobs nécessitant le réseau privé (`kubectl apply`, accès direct RDS).

### Vue plateforme — chemin HTTP synchrone

<p align="center"><img src="docs/diagrams/plateforme-cible.svg" alt="Vue plateforme cible" width="850"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/plateforme-cible.html`](docs/diagrams/plateforme-cible.html) (version archify — composants + boundaries VPC/security-group, export PNG/SVG).

### Vue plateforme — chemin webhook paiement (async)

<p align="center"><img src="docs/diagrams/webhook-paiement-async.svg" alt="Webhook paiement async" width="850"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/webhook-paiement-async.html`](docs/diagrams/webhook-paiement-async.html) (version archify — export PNG/SVG).

> **Clarification terminologique** : deux concepts homonymes coexistent dans ce projet.
> - **API Gateway AWS** : service managé AWS, utilisé uniquement pour le webhook paiement entrant depuis le provider externe.
> - **Gateway API Kubernetes** : spec CNCF implémentée par NGINX, utilisée pour le routage interne au cluster et la validation JWT.

### Vue sécurité des pods EKS

<p align="center"><img src="docs/diagrams/securite-pods-eks.svg" alt="Sécurité des pods EKS" width="1150"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/securite-pods-eks.html`](docs/diagrams/securite-pods-eks.html) (version archify — export PNG/SVG).

> **Lecture** : cette vue montre la **composition interne d'un pod applicatif** et les contrôles qui l'encadrent autour de lui.
> - `init: db-migrate` s'exécute **avant** le conteneur applicatif et bloque le démarrage tant que les migrations ne sont pas terminées.
> - Le conteneur `service-*` porte la logique métier Go.
> - Les `sidecars` ajoutent des capacités transverses sans alourdir l'application elle-même : proxy technique, export de logs, etc.
> - `IRSA` ne vit pas dans le pod : c'est le mécanisme AWS qui donne au **ServiceAccount** un rôle IAM éphémère, donc des credentials courts et ciblés.
> - `Kyverno` et `External Secrets` sont aussi **hors pod** : ce sont des contrôleurs de plateforme qui valident ou alimentent les workloads au niveau du cluster.

> **Ce que la vue veut faire comprendre** :
> - la sécurité d'un pod ne se réduit pas à "un conteneur Go" ;
> - une partie est **dans** le pod (init containers, sidecars), une autre est **autour** du pod (admission, secrets, identité AWS) ;
> - sur EKS, le pod applicatif est donc à la fois un point d'exécution et un point d'intégration avec plusieurs contrôles de plateforme.

### Vue Kubernetes — flux runtime inter-pods

<p align="center"><img src="docs/diagrams/flux-runtime-inter-pods-k8s-icons.svg" alt="Flux runtime inter-pods" width="1200"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/flux-runtime-k8s.html`](docs/diagrams/flux-runtime-k8s.html) (version archify — export PNG/SVG).

> **Lecture** : cette vue ne montre que les flux **runtime**. Elle répond à la question "qui parle à qui pendant l'exécution normale ?" : ALB → Gateway API → `jwt-authorizer` / services Go, DNS via CoreDNS, enforcement via Cilium, observabilité via Hubble.

### Vue Kubernetes — séquence d'une requête runtime

<p align="center"><img src="docs/diagrams/flux-runtime-requete-k8s-sequence.svg" alt="Séquence runtime Kubernetes sur /api/commande" width="1400"></p>

> ✏️ **Source éditable** : [`docs/diagrams/flux-runtime-requete-k8s-sequence.drawio`](docs/diagrams/flux-runtime-requete-k8s-sequence.drawio).

> **But de la vue** : distinguer ce qui est **préparé avant** la requête de ce qui est **réellement traversé pendant** une requête `POST /api/commande`.

**Étapes — ce qu'il se passe concrètement**

1. **Avant la requête, `kube-apiserver` ne route aucun trafic applicatif**. Il porte l'état désiré du cluster : `Services`, `Endpoints`, `NetworkPolicies`, etc.
2. **Le `Cilium agent` consomme cet état** en watchant l'API Kubernetes. Son rôle ici est de charger le datapath avec les bonnes informations de routage et d'enforcement.
3. **Le `Cilium datapath` (eBPF) est donc déjà prêt** quand le trafic arrive. C'est important : au moment de la requête, on ne redemande pas au plan de contrôle "où envoyer le paquet ?".
4. **Le client envoie `POST /api/commande` vers l'ALB**. L'ALB cible ensuite le `Service` exposant la Gateway API.
5. **Le datapath Cilium fait le service load-balancing** vers un vrai pod `Gateway API`. C'est là que la ClusterIP / le `Service` deviennent un endpoint concret.
6. **La Gateway API appelle `jwt-authorizer`** via le mécanisme `auth-request`. Si le JWT Cognito est valide, elle récupère l'autorisation et seulement les **claims utiles** au backend, ici surtout `sub` et `email`, propagés ensuite comme headers de confiance `X-User-Sub` et `X-User-Email`.
7. **La Gateway route ensuite vers le `Service` de `service-commande`**. Là encore, le datapath Cilium traduit ce `Service` vers un pod Go réel.
8. **`service-commande` traite la logique métier**. Si le nom de la base n'est pas déjà en cache, le pod interroge `CoreDNS` pour résoudre l'endpoint RDS.
9. **`CoreDNS` répond uniquement pour la résolution DNS interne ou dépendances nommées**. Il n'est pas le routeur du trafic HTTP lui-même ; il aide le workload à savoir quelle adresse joindre.
10. **Le pod `service-commande` appelle RDS** et fait ici son `INSERT commande`, puis reçoit la réponse SQL de retour.
11. **La réponse remonte ensuite en sens inverse** : `service-commande` → Gateway API → ALB → client.
12. **`Hubble` n'est pas dans le hot path**. Il observe les flux et verdicts Cilium pour l'explication et le diagnostic, mais ne traite pas la requête applicative inline.

> **Mental model utile** :
> - `kube-apiserver` et `Cilium agent` servent surtout à **préparer** le chemin.
> - `Cilium datapath`, la Gateway, `jwt-authorizer`, le pod Go et éventuellement `CoreDNS` servent à **faire passer** la requête.
> - `Hubble` sert à **voir** ce qu'il s'est passé, pas à faire réussir la requête.
>
> **À propos de Cilium et du chemin retour** :
> - Le trafic **east-west** correspond aux flux **internes au cluster** : par exemple `Gateway API` → `service-commande`, ou `service-commande` → `CoreDNS`.
> - Le trafic **north-south** correspond aux flux **entre l'extérieur et le cluster** : par exemple client Internet → ALB → cluster.
> - Sur l'east-west, Cilium optimise déjà le load-balancing des `Service` Kubernetes dans le cluster.
> - Cilium supporte aussi un mode **DSR** (*Direct Server Return*) pour certains flux L4 north-south, où la réponse peut repartir plus directement depuis le backend.
> - **Ce n'est pas le modèle de notre flux HTTP principal** : ici le client parle au couple `ALB` + `Gateway API / NGINX`, puis la Gateway appelle le backend Go. Le service Go répond donc à la Gateway, et la Gateway répond au client. On reste dans un modèle **reverse proxy L7**, pas dans un service L4 exposant directement un backend au client final.

### Vue Kubernetes — control plane

<p align="center"><img src="docs/diagrams/control-plane-k8s.svg" alt="Control plane Kubernetes" width="900"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/control-plane-k8s.html`](docs/diagrams/control-plane-k8s.html) (version archify — export PNG/SVG).

> **Lecture** : cette vue sépare les flux de **pilotage du cluster** des flux applicatifs. Elle montre qui configure l'état désiré (Argo CD), qui projette les secrets (External Secrets), et qui charge / observe les règles réseau (Cilium + Hubble).

### Vue DevSecOps — shift-left

<p align="center"><img src="docs/diagrams/devsecops-shift-left.svg" alt="DevSecOps shift-left" width="850"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/devsecops-shift-left.html`](docs/diagrams/devsecops-shift-left.html) (version archify — export PNG/SVG).

> **Lecture** : cette vue montre une **défense en profondeur** plutôt qu'un simple scan CI. Les contrôles commencent très tôt sur le poste local (`detect-secrets`, `hadolint`, `tfsec`), continuent dans la pipeline sur les artefacts et dépendances (`GitLeaks`, `Trivy`, `OWASP`), puis se prolongent dans le cluster (`Kyverno`, `Falco`, `Cilium`, `ESO`) et au niveau du compte AWS (`Security Hub`, `AWS Config`, `SCPs`, détection d'anomalies de coût).

> **Mental model utile** :
> - Le **poste local** évite de pousser des erreurs triviales ou des secrets.
> - La **CI** décide si un artefact mérite d'être promu.
> - Le **runtime EKS** applique les garde-fous au moment réel d'exécution.
> - La **posture AWS** surveille ce qui dépasse le cluster : compte, organisations, dérive et coût.

### Flux GitOps

<p align="center"><img src="docs/diagrams/pipeline-gitops.svg" alt="Pipeline CI/CD vers GitOps" width="850"></p>

> 📊 **Diagramme interactif** : [`docs/diagrams/pipeline-gitops.html`](docs/diagrams/pipeline-gitops.html) (version archify — export PNG/SVG).

> **Lecture** : ce flux sépare bien la **validation** de l'artefact et la **mise à jour GitOps**. Le pipeline build l'image, produit son digest immuable `sha256`, exécute les scans DevSecOps, puis seulement si les gates passent déclenche l'étape dédiée `update-gitops-tag` qui patch le repo GitOps. Ensuite Argo CD détecte ce changement et synchronise le cluster.

> **Point de vigilance** : `Trivy` **ne fait pas** le tag GitOps. Son rôle est de **bloquer ou laisser passer** l'artefact. Le commit GitOps est fait par l'étape dédiée `update-gitops-tag`, typiquement avec `[skip ci]`, pour écrire le nouveau digest dans les manifests suivis par Argo CD.

---

## Structure du repo

```
idp-platform/
│
├── ansible/                          # Sprint 0 — provisioning local + au-delà
│   ├── roles/
│   │   ├── k3s-install/              # k3s sans CNI par défaut
│   │   ├── cilium-setup/             # Cilium via Helm + Hubble
│   │   ├── ministack-setup/          # Docker + MiniStack + profil AWS CLI
│   │   ├── cloudflare-tunnel/        # cloudflared — exposition locale sécurisée
│   │   ├── gitlab-runner/            # runner Docker executor (local ET EC2 bootstrap)
│   │   └── node-hardening/           # CIS baseline — Ubuntu (local/EC2) + AL2023 (ansible-pull)
│   ├── playbooks/
│   │   ├── bootstrap.yml             # tout en une commande (serveur local)
│   │   ├── runner-setup.yml          # configure EC2 runner bootstrap post-Terraform
│   │   ├── rds-setup.yml             # databases + users PostgreSQL (least privilege)
│   │   ├── gitea-setup.yml           # org + repos + token bot GitOps post-déploiement
│   │   ├── harden.yml                # CIS — joué localement ou via ansible-pull
│   │   └── teardown.yml              # remet le serveur à zéro
│   ├── inventory/
│   │   ├── local.yml                 # serveur Ubuntu local
│   │   └── aws_ec2.yml               # dynamic inventory — EC2 runner + nodes EKS
│   ├── group_vars/all.yml
│   └── molecule/                     # tests des roles (driver Docker)
│
├── bootstrap/                         # State Terraform permanent — jamais détruit
│   ├── terraform/
│   │   ├── ec2-runner/                # EC2 t3.micro Ubuntu + SG + IAM (GitLab runner)
│   │   ├── s3-state/                  # bucket tfstate workload + DynamoDB lock
│   │   └── gitlab-oidc/               # provider OIDC + rôle IAM scopé project/branch
│   └── ansible/
│       └── runner-init.sh             # user_data minimal → ansible-pull
│
├── landing-zone/                     # Sprint 2 — Landing Zone AWS
│   ├── terraform/
│   │   ├── modules/
│   │   │   ├── aws-organization/     # Organizations + OUs + comptes enfants
│   │   │   ├── aws-scp/              # Service Control Policies (testées en sandbox)
│   │   │   ├── aws-sso/              # IAM Identity Center + permission sets
│   │   │   └── aws-baseline/         # CloudTrail + Config minimal + Budgets + Cost Anomaly
│   │   │                              # flag enable_full_posture (GuardDuty + CIS complet)
│   │   ├── envs/root/
│   │   └── ministack/                # override provider pour validation locale
│   └── docs/
│       ├── architecture.md
│       ├── account-vending.md
│       └── scp-global-services.md    # services globaux exclus de deny-regions-outside-eu
│
├── platform/                         # Sprints 3-4
│   ├── terraform/
│   │   ├── modules/
│   │   │   ├── eks-cluster/          # EKS + Karpenter (AL2023) + IRSA + addons + control plane logs
│   │   │   ├── vpc/                  # subnets, NAT Gateway, Flow Logs, VPC Endpoints
│   │   │   ├── irsa-role/            # IAM role + OIDC + annotation SA
│   │   │   ├── rds-postgres/         # RDS multi-AZ + backup + Secrets Manager + PITR testé
│   │   │   ├── sns-fanout/           # topic SNS + 2 queues SQS abonnées + DLQ
│   │   │   ├── cloudfront-waf/       # distribution + WAF WebACL
│   │   │   ├── alb/                  # AWS Load Balancer Controller + ALB
│   │   │   └── api-gateway-webhook/  # API Gateway + Lambda webhook-paiement + HMAC
│   │   └── envs/
│   │       ├── staging/
│   │       └── prod/
│   ├── k8s/
│   │   ├── argocd/
│   │   │   ├── applicationset-staging.yaml
│   │   │   └── applicationset-prod.yaml
│   │   ├── cilium/                   # NetworkPolicies (default-deny + allow explicite)
│   │   ├── gateway-api/              # GatewayClass, Gateway, HTTPRoutes + JWT filter
│   │   ├── kyverno/                  # policies admission control
│   │   ├── karpenter/                # NodePool Spot + Graviton
│   │   ├── hpa/                      # HorizontalPodAutoscaler par service
│   │   ├── pdb/                      # PodDisruptionBudgets par service
│   │   └── external-secrets/         # ExternalSecret manifests
│   └── monitoring/
│       ├── prometheus/               # rules + runbooks liés via runbook_url
│       ├── loki/
│       ├── grafana/
│       └── kubecost/
│
├── devsecops/                        # Sprint 5
│   ├── pre-commit/
│   │   └── .pre-commit-config.yaml
│   ├── threat-model/
│   │   └── shopdemo.dtd              # OWASP Threat Dragon — menaces STRIDE par composant
│   └── policies/
│       ├── kyverno/
│       └── falco/
│
├── ci/                               # Sprint 6
│   ├── components/
│   │   ├── build-image/              # Kaniko + digest sha256 + SBOM CycloneDX
│   │   ├── scan-security/            # Trivy + OWASP + GitLeaks (DAG parallel)
│   │   └── update-gitops-tag/        # patch digest + [skip ci] + token bot Gitea
│   ├── terraform/
│   │   └── gitlab-oidc/              # provider OIDC + rôle IAM + EKS Access Entries
│   └── .gitlab-ci.yml
│
└── apps/
    └── shopdemo/
        ├── frontend/
        ├── service-catalogue/        # Go
        ├── service-panier/           # Go
        ├── service-commande/         # Go — publie sur SNS commande-créée
        ├── service-paiement/         # Go — paiement synchrone
        ├── lambda-webhook-paiement/  # Lambda Go — reçoit callback provider
        ├── service-stock/            # Go — consomme SQS queue-stock
        ├── service-notification/     # Go — consomme SQS queue-notification
        ├── bruno/
        └── docker-compose.yml
```

---

## Sprints

Détail complet des objectifs, livrables et extraits techniques par sprint : [`docs/sprint-planning.md`](docs/sprint-planning.md). Suivi d'avancement (état, blocages, preuves) : [`README.md`](README.md#où-en-est-le-projet) et `docs/sprints/sprint-N-*.md`.

| Sprint | Sujet | Durée | Coût AWS | Lacunes adressées |
|---|---|---|---|---|
| [0](docs/sprint-planning.md#sprint-0--ansible--provisioning-local--fondations-bootstrap) | Ansible : provisioning local + fondations bootstrap | 2 semaines | 0$ (local) + ~5$/mois (bootstrap EC2) | Ansible, idempotence, Molecule, dynamic inventory |
| [1](docs/sprint-planning.md#sprint-1--argo-cd-et-base-gitops-locale) | Argo CD et base GitOps locale | 2 semaines | 0$ | Argo CD multi-env, GitOps branching |
| [2](docs/sprint-planning.md#sprint-2--landing-zone--terraform-modules-aws-organizations) | Landing Zone : Terraform modules AWS Organizations | 2 semaines | ~5$/mois (permanent) | Landing Zone AWS, SCPs, IAM Identity Center, FinOps posture-toggle |
| [3](docs/sprint-planning.md#sprint-3--platform--modules-terraform-eks--réseau--services-aws) | Platform : modules Terraform EKS + réseau + services AWS | 3 semaines | ~3-5$/session | IRSA, Karpenter, CloudFront, WAF, Gateway API, Cognito, SNS/SQS fan-out |
| [4](docs/sprint-planning.md#sprint-4--observabilité--stack-plg--dashboards-shopdemo) | Observabilité : stack PLG + dashboards ShopDemo | 2 semaines | ~3-5$/session | Loki (alternative ELK), observabilité applicative, cost visibility EKS |
| [5](docs/sprint-planning.md#sprint-5--devsecops--shift-left-complet) | DevSecOps : shift-left complet | 2 semaines | ~3-5$/session | Sécurité Kubernetes, secrets, admission control, threat modeling |
| [6](docs/sprint-planning.md#sprint-6--cicd--pipeline-gitlab--components-réutilisables) | CI/CD : pipeline GitLab + Components réutilisables | 2 semaines | ~3-5$/session | GitLab Components, OIDC auth AWS, supply chain SLSA, upgrade EKS |

---

## Risques assumés

| Risque | Acceptation | Mitigation |
|---|---|---|
| Pas de multi-région | Accepté — coût et complexité disproportionnés pour un lab | Infrastructure 100% IaC, reconstructible dans une autre région en changeant une variable ; backups RDS exportables |
| GuardDuty/Config CIS intermittents hors session | Accepté — `enable_full_posture` réduit la détection entre les sessions | Budgets + Cost Anomaly Detection actifs en permanence ; aucune donnée réelle ne transite hors session |
| EKS disproportionné pour ShopDemo | Accepté — objectif est la montée en compétences platform engineering, pas l'optimisation du coût applicatif | Modules Terraform opinionated et réutilisables, GitOps de bout en bout — la complexité est "payée une fois" et amortie sur 4 sprints |
| Spot interruption sur les nodes Karpenter | Accepté — réduction de coût ~70% vs On-Demand | PDB (`minAvailable: 1`), HPA, NodePool avec fallback `on-demand` si capacité Spot indisponible |
| NAT Gateway conservé malgré les VPC Endpoints | Accepté — élimination complète nécessiterait de couvrir toutes les dépendances externes (registries publiques, Gitea/GitLab, OCSP) | VPC Endpoints couvrent le trafic AWS-to-AWS à fort volume ; NAT résiduel limité au trafic non-AWS |
| Thumbprint OIDC statique | Accepté — rotation rare du certificat racine gitlab.com | Vérification annuelle documentée dans `platform/docs/oidc-maintenance.md` |
| Pas de compte `log-archive` / `network` dédiés | Accepté — 4 comptes suffisent à démontrer les concepts multi-comptes | SCPs + CloudTrail centralisé dans le compte audit ; documenté comme limite connue (cf. section Landing Zone) |

---

## Matrice de preuves — contrôles critiques

Pour chaque contrôle de sécurité/fiabilité majeur, l'artefact attendu et le sprint où il est produit. Sert de checklist d'implémentation et de référence d'audit.

| Contrôle | Preuve attendue | Sprint |
|---|---|---|
| RDS chiffré + backup + PITR testé | Module `rds-postgres` (KMS, `backup_retention_period`), test restore documenté | Sprint 3 |
| IRSA — pas de credentials node sur les pods | Module `irsa-role`, annotations ServiceAccount par service | Sprint 3 |
| IMDSv2 enforced sur les nodes | `EC2NodeClass.metadataOptions.httpTokens: required` | Sprint 3 |
| Control plane EKS — logs complets | `enabled_cluster_log_types` (5 types), CloudWatch Logs | Sprint 3 |
| DLQ par queue + idempotence | Module `sns-fanout`, table `processed_events`, alerte `DLQ depth > 0` | Sprint 3/4 |
| Secrets jamais en clair | External Secrets Operator + Secrets Manager, aucun `Secret` créé manuellement | Sprint 3/5 |
| Images digest-pinned en prod | GitOps `values.yaml` (`@sha256:`), Kyverno `disallow-latest-tag` | Sprint 5/6 |
| Admission control runtime | Policies Kyverno (`runAsNonRoot`, `resources.limits`, labels obligatoires) | Sprint 5 |
| SCPs testées avant application | Plan Terraform contre compte sandbox, `docs/scp-global-services.md` | Sprint 2 |
| OIDC GitLab scopé project/branch | Module `gitlab-oidc`, trust policy `gitlab.com:sub` | Sprint 6 |
| EKS Access Entries scopées namespace | `aws_eks_access_policy_association`, `access_scope.namespaces` | Sprint 6 |
| Runbooks par alerte critique | `monitoring/runbooks/*.md`, annotation `runbook_url` | Sprint 4 |

---

## Récapitulatif

### Lacunes couvertes

| Lacune | Sprint | Niveau attendu post-projet |
|---|---|---|
| Ansible + Molecule + frontière Terraform/Ansible | Sprint 0 | Playbooks idempotents, roles testés, Cloudflare Tunnel, RDS/Gitea/runner playbooks |
| CNI Kubernetes (Cilium, replacement mode local) | Sprint 0 | Déploiement k3s, NetworkPolicy, Hubble |
| CNI Kubernetes (Cilium, chaining mode EKS) | Sprint 3 | Chaining avec le VPC CNI, NetworkPolicy, Hubble en environnement AWS |
| Argo CD multi-env | Sprint 1 | ApplicationSet, branching strategy, sync waves, selfHeal |
| Landing Zone AWS + FinOps posture-toggle | Sprint 2 | Organizations, OUs, SCPs (incl. piège global services), IAM Identity Center, GuardDuty on/off |
| Terraform modules custom + 2 states (bootstrap/workload) | Sprints 2 & 3 | Modules internes versionnés, opinionated, séparation des cycles de vie |
| CloudFront + WAF | Sprint 3 | CDN edge, protection couche 7 |
| Gateway API (NGINX) + JWT auth | Sprint 3 | GatewayClass / HTTPRoute, frontière d'auth unique |
| Init containers + sidecars | Sprint 3 | fluent-bit, sqs-producer-proxy, db-migrate |
| Cognito + jwt-authorizer (ExternalAuth) | Sprint 3 | Auth utilisateurs, authorizer central JWKS/issuer/audience |
| Lambda webhook + API Gateway AWS | Sprint 3 | Pattern serverless event-driven, HMAC, use case naturel |
| RDS backup/restore + Ansible post-provisioning | Sprint 3 | Snapshot, PITR testé, rotation secrets, databases least-privilege |
| SNS fan-out + SQS + idempotence | Sprint 3 | Pattern pub/sub, DLQ, IRSA par queue, table `processed_events`, réconciliation |
| FinOps EKS + Amazon Linux 2023 | Sprint 3 | Spot, Graviton, AL2023, VPC Endpoints, topology-aware routing |
| HPA + PDB + probes | Sprint 3 | Autoscaling horizontal, résilience rolling update |
| Hardening CIS multi-OS (ansible-pull) | Sprint 3 | Ubuntu local + AL2023 nodes EKS, sans SSH sortant |
| Loki (alternative ELK) | Sprint 4 | PLG stack complète, LogQL de base |
| Kubecost | Sprint 4 | Cost allocation namespace-level sur EKS |
| Runbooks | Sprint 4 | Alerte → procédure de résolution |
| DevSecOps shift-left | Sprint 5 | Pre-commit, Trivy, OWASP, Kyverno, secrets, digest pinning |
| Threat model | Sprint 5 | OWASP Threat Dragon, STRIDE par composant |
| GitLab Components + OIDC AWS + répartition runners | Sprint 6 | Components paramétrables, zéro clé IAM en CI, shared vs EC2 runner |
| Kaniko (rootless build) | Sprint 6 | Build sans privileged, alternative DinD |
| SBOM CycloneDX | Sprint 6 | Supply chain SLSA L2, traçabilité des images |
| Protected Environment + approbation | Sprint 6 | Governance prod, gate humain obligatoire |
| EKS Access Entries scopées | Sprint 6 | Accès pipeline cloisonné au namespace shopdemo |
| Frontend S3 + CloudFront CI | Sprint 6 | Deploy S3, invalidation cache |
| Upgrade EKS | Sprint 6 | kubent, rotation Karpenter, compatibility matrix |

### Budget AWS total estimé

| Poste | Coût |
|---|---|
| Landing Zone permanente (~5$/mois × 3 mois) | ~15$ |
| EC2 runner bootstrap (~5$/mois × 3 mois, t3.micro) | ~15$ |
| Sessions EKS/VPC/RDS/SQS (~15-20 sessions × $0.6-0.9/h × 4-6h, Spot+Graviton+AL2023) | ~70-130$ |
| Posture renforcée pendant sessions (GuardDuty + Config CIS, ~15 sessions × 4$/jour) | ~15-25$ |
| **Total projet** | **~115-185$** |

---

## Références

- [Terraform AWS modules](https://registry.terraform.io/namespaces/terraform-aws-modules)
- [Cilium docs](https://docs.cilium.io)
- [Cilium EKS chaining mode](https://docs.cilium.io/en/stable/installation/k8s-install-eks/)
- [Argo CD ApplicationSet](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [AWS Landing Zone Accelerator](https://aws.amazon.com/solutions/implementations/landing-zone-accelerator-on-aws/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter docs](https://karpenter.sh/docs/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Loki architecture](https://grafana.com/docs/loki/latest/get-started/architecture/)
- [Kubecost](https://www.kubecost.com/)
- [GitLab CI Components](https://docs.gitlab.com/ee/ci/components/)
- [GitLab OIDC AWS](https://docs.gitlab.com/ee/ci/cloud_services/aws/)
- [Kaniko — rootless image builder](https://github.com/GoogleContainerTools/kaniko)
- [Molecule testing](https://ansible.readthedocs.io/projects/molecule/)
- [dev-sec.os-hardening](https://github.com/dev-sec/ansible-collection-hardening)
- [Kyverno policies](https://kyverno.io/policies/)
- [External Secrets Operator](https://external-secrets.io)
- [MiniStack](https://ministack.dev)
- [Bruno API client](https://www.usebruno.com/)
- [Pico.css](https://picocss.com/)
- [OWASP Threat Dragon](https://owasp.org/www-project-threat-dragon/)
- [kubent — deprecated API detector](https://github.com/doitintl/kube-no-trouble)
