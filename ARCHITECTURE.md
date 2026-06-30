# IDP Platform — Internal Developer Platform

> Projet personnel de montée en compétences DevOps/Cloud Architecture.  
> Une plateforme de déploiement interne complète, construite autour d'une application e-commerce de démonstration, auto-hébergée sur serveur Ubuntu local avec une architecture cible AWS multi-comptes.

---

## Contexte fonctionnel

La plateforme héberge **ShopDemo**, une application e-commerce minimaliste servant de fil conducteur technique. L'application est volontairement simple côté métier — l'objectif est de justifier naturellement chaque choix d'architecture.

### Ce que fait ShopDemo

Un utilisateur peut s'inscrire, parcourir un catalogue de produits, ajouter des articles à son panier, passer une commande et effectuer un paiement simulé.

```mermaid
sequenceDiagram
    actor U as Utilisateur
    participant CF as CloudFront
    participant S3
    participant NGINX as Gateway API (NGINX)
    participant SP as service-paiement (Go)
    participant SC as service-commande (Go)
    participant RDS
    participant SNS
    participant SQS1 as SQS queue-stock
    participant SQS2 as SQS queue-notification
    participant APIGW as API Gateway AWS
    participant LBD as Lambda webhook-paiement

    U->>CF: GET / (frontend)
    CF->>S3: GET assets statiques
    S3-->>U: HTML/CSS/JS

    U->>CF: POST /api/commande (JWT)
    CF->>NGINX: route /api/*
    NGINX->>SC: JWT validé → créer commande
    SC->>RDS: INSERT commande
    SC->>SNS: publish "commande-créée"
    SNS->>SQS1: fan-out queue-stock
    SNS->>SQS2: fan-out queue-notification

    U->>CF: POST /api/paiement (JWT)
    CF->>NGINX: route /api/*
    NGINX->>SP: JWT validé → paiement simulé
    SP-->>U: 200 OK (succès simulé)

    Note over APIGW,LBD: Chemin async — provider simulé
    APIGW->>LBD: POST /webhook/paiement (API Key + HMAC)
    LBD->>SNS: publish "paiement-confirmé"
    SNS->>SQS1: décrémente stock
    SNS->>SQS2: log confirmation
```

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

```mermaid
graph TD
    MA[Management account] --> ORG[AWS Organizations]
    ORG --> AUDIT[compte audit<br/>+audit@gmail.com]
    ORG --> STAGING[compte staging<br/>+staging@gmail.com]
    ORG --> PROD[compte prod<br/>+prod@gmail.com]
    ORG --> SANDBOX[compte sandbox<br/>+sandbox@gmail.com]

    style MA fill:#E6F1FB,stroke:#185FA5,color:#0C447C
    style AUDIT fill:#EAF3DE,stroke:#3B6D11,color:#27500A
    style STAGING fill:#EAF3DE,stroke:#3B6D11,color:#27500A
    style PROD fill:#EAF3DE,stroke:#3B6D11,color:#27500A
    style SANDBOX fill:#F1EFE8,stroke:#5F5E5A,color:#444441
```

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

---

## Architecture cible

### Vue organisation AWS

```mermaid
graph TD
    MGMT["Management account<br/>Control Tower · SCPs · Billing · IAM Identity Center"]

    MGMT --> SEC["OU: Security"]
    MGMT --> WRK["OU: Workloads"]
    MGMT --> SBX["OU: Sandbox"]

    SEC --> AUDIT["audit account"]
    WRK --> STAGING["staging account"]
    WRK --> PROD["prod account"]

    subgraph SCPs["SCPs appliquées"]
        S1["deny-root-usage"]
        S2["deny-regions-outside-eu ¹"]
        S3["enforce-cloudtrail"]
        S4["deny-public-s3"]
        S5["require-mfa-for-console"]
        S6["deny-iam-longterm-keys"]
    end

    style MGMT fill:#E6F1FB,stroke:#185FA5,color:#0C447C
    style AUDIT fill:#FAEEDA,stroke:#BA7517,color:#633806
    style STAGING fill:#EAF3DE,stroke:#3B6D11,color:#27500A
    style PROD fill:#EAF3DE,stroke:#3B6D11,color:#27500A
```

> **¹ SCP `deny-regions-outside-eu`** : s'applique uniquement aux services régionaux. Les services globaux (`iam`, `route53`, `cloudfront`, `sts`, `support`, `s3` control plane) sont explicitement exclus. Testé en compte sandbox avant déploiement sur prod OU.

### Vue Terraform — 2 states séparés (bootstrap vs workload)

```mermaid
flowchart TD
    subgraph BOOTSTRAP["State bootstrap — permanent, jamais détruit"]
        direction TB
        B1["EC2 runner (Ubuntu, t3.micro)<br/>GitLab runner enregistré"]
        B2["S3 bucket tfstate workload<br/>+ DynamoDB lock table"]
        B3["Provider OIDC GitLab → AWS<br/>+ rôle IAM scopé project/branch"]
    end

    subgraph WORKLOAD["State workload — détruit après chaque session"]
        direction TB
        W1["VPC + EKS + Karpenter<br/>(Amazon Linux 2023)"]
        W2["RDS · SNS/SQS · CloudFront/WAF"]
        W3["Cognito · API Gateway · Lambda"]
    end

    GLSHARED["GitLab shared runners<br/>(tier gratuit, 400 min/mois)"]
    ECRUN["EC2 runner (bootstrap)"]

    GLSHARED -->|"terraform apply/destroy<br/>bootstrap/ (rare, manuel)"| BOOTSTRAP
    BOOTSTRAP --> ECRUN
    GLSHARED -->|"terraform apply<br/>envs/staging/ (début session)"| WORKLOAD
    ECRUN -->|"kubectl apply, jobs réseau privé"| WORKLOAD
    GLSHARED -->|"terraform destroy<br/>envs/staging/ (fin session)"| WORKLOAD

    style BOOTSTRAP fill:#EAF3DE,stroke:#3B6D11,color:#27500A
    style WORKLOAD fill:#E6F1FB,stroke:#185FA5,color:#0C447C
```

> **Pourquoi 2 states** : le state `bootstrap` contient l'EC2 runner et le bucket S3 qui héberge le state `workload`. Si tout était dans un seul state, `terraform destroy` détruirait le runner en train d'exécuter le destroy — le serpent qui se mord la queue. Apply ET destroy du state `workload` tournent sur les **shared runners GitLab.com** (gratuits, hors du cycle de vie qu'ils gèrent) ; le **EC2 runner bootstrap** prend en charge les jobs nécessitant le réseau privé (`kubectl apply`, accès direct RDS).

### Vue plateforme — chemin HTTP synchrone

```mermaid
flowchart TD
    USER([Utilisateur])
    CF["CloudFront + WAF<br/>HTTPS, cache, compression"]
    S3["S3<br/>frontend statique + images"]
    ALB["ALB<br/>AWS Load Balancer Controller"]
    GW["Gateway API — NGINX Gateway Fabric<br/>GatewayClass : platform team"]
    AUTHZ["jwt-authorizer<br/>ExternalAuth — valide JWT Cognito<br/>JWKS, issuer, audience"]

    USER --> CF
    CF -->|"GET /"| S3
    CF -->|"/api/*"| ALB
    ALB --> GW
    GW -.->|"ExtensionRef auth-request<br/>(routes protégées)"| AUTHZ

    subgraph VPC["VPC — subnets privés 3 AZs"]
        subgraph EKS["EKS cluster"]
            GW -->|HTTPRoute| CAT["service-catalogue (Go)"]
            GW -->|HTTPRoute| PAN["service-panier (Go)"]
            GW -->|HTTPRoute| CMD["service-commande (Go)"]
            GW -->|HTTPRoute| PAY["service-paiement (Go)"]
        end

        CMD -->|publish| SNS1["SNS commande-créée"]
        SNS1 --> SQSS["SQS queue-stock"]
        SNS1 --> SQSN["SQS queue-notification"]

        subgraph RDS["RDS PostgreSQL (t4g Graviton, Multi-AZ)"]
        end

        CAT & PAN & CMD & PAY --> RDS
    end

    subgraph VPCEndpoints["VPC Endpoints — trafic AWS-to-AWS privé"]
        EP["ecr.api · ecr.dkr · sqs<br/>secretsmanager · sts · s3"]
    end

    subgraph NATBOX["NAT Gateway — trafic non-AWS"]
        NAT["images publiques, deps Go,<br/>Gitea/GitLab, OCSP/CRL"]
    end
```

### Vue plateforme — chemin webhook paiement (async)

```mermaid
flowchart LR
    PROVIDER([Provider paiement<br/>simulé])
    APIGW["API Gateway AWS<br/>API Key + validation HMAC"]
    LBD["Lambda<br/>webhook-paiement"]
    SNS2["SNS paiement-confirmé"]
    SQSS2["SQS queue-stock"]
    SQSN2["SQS queue-notification"]
    STOCK["service-stock (Go)"]
    NOTIF["service-notification (Go)"]

    PROVIDER -->|"POST /webhook/paiement"| APIGW
    APIGW --> LBD
    LBD --> SNS2
    SNS2 --> SQSS2
    SNS2 --> SQSN2
    SQSS2 --> STOCK
    SQSN2 --> NOTIF

    style APIGW fill:#EEEDFE,stroke:#534AB7,color:#3C3489
    style LBD fill:#EEEDFE,stroke:#534AB7,color:#3C3489
```

> **Clarification terminologique** : deux concepts homonymes coexistent dans ce projet.
> - **API Gateway AWS** : service managé AWS, utilisé uniquement pour le webhook paiement entrant depuis le provider externe.
> - **Gateway API Kubernetes** : spec CNCF implémentée par NGINX, utilisée pour le routage interne au cluster et la validation JWT.

### Vue sécurité des pods EKS

```mermaid
flowchart TD
    subgraph POD_CMD["Pod service-commande"]
        SC_SQ["sidecar sqs-producer-proxy<br/>buffer + retry SNS"]
        SC_FB["sidecar fluent-bit<br/>logs → Loki"]
        IC_CMD["init: db-migrate<br/>migrations SQL avant démarrage"]
        APP_CMD["service-commande (Go)"]
        IC_CMD --> APP_CMD
    end

    subgraph POD_CAT["Pod service-catalogue"]
        SC_FB2["sidecar fluent-bit"]
        IC_CAT["init: db-migrate"]
        APP_CAT["service-catalogue (Go)"]
        IC_CAT --> APP_CAT
    end

    IRSA["IRSA<br/>IAM role par service account<br/>credentials éphémères"]
    KYV["Kyverno<br/>admission control"]
    ESO["External Secrets Operator<br/>Secrets Manager → K8s Secret"]

    KYV -->|"vérifie policies"| POD_CMD
    KYV -->|"vérifie policies"| POD_CAT
    ESO -->|"injecte secrets"| POD_CMD
    ESO -->|"injecte secrets"| POD_CAT
    IRSA -->|"SQS, SNS, S3"| POD_CMD
```

### Vue DevSecOps — shift-left

```mermaid
flowchart TD
    subgraph LOCAL["Poste local"]
        direction LR
        DS["detect-secrets"]
        HD["hadolint"]
        TF["tfsec"]
    end

    subgraph CI["Pipeline CI (GitLab)"]
        direction LR
        GL["GitLeaks"]
        TR["Trivy<br/>image + IaC"]
        OW["OWASP<br/>Dep-Check"]
        DP["digest pinning<br/>sha256"]
    end

    subgraph RUNTIME["EKS runtime"]
        direction LR
        KY["Kyverno<br/>policies"]
        FA["Falco"]
        CN["Cilium<br/>NetworkPol"]
        EX["External<br/>Secrets Op"]
    end

    subgraph AWS["AWS posture"]
        direction LR
        SH["Security Hub"]
        GD["GuardDuty"]
        AC["AWS Config"]
        SC["SCPs"]
        CA["Cost Anomaly"]
    end

    LOCAL -->|"bloque le commit"| CI
    CI -->|"bloque si CRITICAL"| RUNTIME
    RUNTIME <-->|"findings"| AWS
```

### Flux GitOps

```mermaid
flowchart TD
    DEV([Dev push]) --> GITLAB["GitLab CI"]

    GITLAB --> GL["GitLeaks<br/>scan historique Git"]
    GITLAB --> OW["OWASP Dep-Check"]
    GITLAB --> BUILD["Build image Docker<br/>multi-stage"]
    BUILD --> TRIVY["Trivy<br/>image + IaC<br/>bloque si CVE CRITICAL"]
    TRIVY --> TAG["Component update-gitops-tag<br/>patch digest sha256"]

    TAG --> GITOPS["Gitea repo GitOps"]
    GITOPS -->|"merge PR"| STAGING["k8s/staging/"]
    GITOPS -->|"tag vX.Y.Z"| PROD["k8s/prod/"]

    STAGING & PROD --> ARGO["Argo CD ApplicationSet"]

    subgraph WAVES["Sync waves"]
        W1["wave -5 : Namespaces, CRDs"]
        W2["wave -2 : ExternalSecrets → K8s Secrets"]
        W3["wave 0 : Deployments + probes"]
        W4["wave 2 : HTTPRoutes"]
        W1 --> W2 --> W3 --> W4
    end

    ARGO --> WAVES
    WAVES --> KYV["Kyverno admission control<br/>vérifie policies avant scheduling"]
```

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

### Sprint 0 — Ansible : provisioning local + fondations bootstrap

**Durée estimée :** 2 semaines | **Coût AWS :** 0$ (local) + ~5$/mois (bootstrap EC2, dès activation)  
**Lacunes adressées :** Ansible, idempotence, Molecule, dynamic inventory, frontière Terraform/Ansible

**Objectif :** rendre le serveur Ubuntu entièrement reproductible via un seul playbook, ET poser la frontière Terraform (provisionne) / Ansible (configure) qui sera réutilisée sur l'EC2 runner, RDS et Gitea dans les sprints suivants.

**Molecule** crée un container Docker, joue le role dedans, vérifie le résultat, puis vérifie l'idempotence en rejouant le role une seconde fois — un role correct ne doit rien modifier au second passage.

**Livrables — serveur local :**

- Role `k3s-install` — k3s sans CNI par défaut, kubeconfig configuré
- Role `cilium-setup` — Cilium via Helm, Hubble activé (mode replacement sur k3s)
- Role `ministack-setup` — Docker + MiniStack + profil AWS CLI `ministack`
- Role `cloudflare-tunnel` — cloudflared installé, sous-domaines `argocd.`, `grafana.`, `gitea.` — exposition sans port entrant
- Role `gitlab-runner` — runner enregistré en mode Docker executor
- Role `node-hardening` — baseline CIS via `dev-sec.os-hardening` (Ubuntu)
- Playbook `bootstrap.yml` — orchestre tous les roles, idempotent
- Playbook `teardown.yml` — remet le serveur à zéro
- Tests Molecule sur chaque role : converge → idempotency → verify
- Inventory `aws_ec2.yml` — dynamic inventory, couvrira l'EC2 runner et les nodes EKS

**Livrables — frontière Terraform/Ansible (préparation Sprint 3) :**

- Playbook `runner-setup.yml` — configure l'EC2 runner bootstrap après sa création par Terraform (Docker, gitlab-runner, enregistrement token)
- Playbook `rds-setup.yml` — crée les databases et users PostgreSQL avec privilèges least-privilege, une fois RDS provisionné par Terraform
- Playbook `gitea-setup.yml` — configure l'organisation, les repos et le token bot GitOps via l'API Gitea après déploiement Helm

```yaml
# ansible/playbooks/rds-setup.yml — extrait
- name: Initialise les databases ShopDemo
  hosts: localhost
  tasks:
    - name: Crée les databases par service
      community.postgresql.postgresql_db:
        name: "{{ item }}"
        state: present
      loop: [catalogue, panier, commande, stock]

    - name: Crée les users avec least privilege
      community.postgresql.postgresql_user:
        name: "svc_{{ item }}"
        password: "{{ lookup('aws_ssm', '/shopdemo/' + item + '/db_password') }}"
        priv: "{{ item }}:ALL"
      loop: [catalogue, panier, commande, stock]
```

---

### Sprint 1 — Kubernetes : k3s + Cilium + Argo CD multi-environnements

**Durée estimée :** 2 semaines | **Coût AWS :** 0$  
**Lacunes adressées :** CNI (Cilium), Argo CD multi-env, GitOps branching strategy

**Objectif :** cluster k3s opérationnel avec Cilium comme CNI et Argo CD déployant sur deux environnements depuis des sources Git distinctes.

**Livrables :**

- k3s sans CNI par défaut (`--flannel-backend=none --disable-network-policy`)
- Cilium via Helm en **replacement mode** (k3s local) — IPAM cluster-pool, Hubble activé
- NetworkPolicies : default-deny ingress/egress par namespace, allow explicite inter-services
- Argo CD + `ApplicationSet` staging (watch branche `staging`, déploiement auto sur merge)
- Argo CD + `ApplicationSet` prod (watch tags `v*.*.*`, déploiement auto sur tag semver)
- **Sync waves** : CRDs (wave -5) → ExternalSecrets (wave -2) → Deployments (wave 0) → HTTPRoutes (wave 2)
- `docker-compose.yml` pour le dev local sans Kubernetes

```yaml
# applicationset-staging.yaml — extrait
spec:
  generators:
    - git:
        repoURL: https://gitea.local/org/idp-gitops.git
        revision: staging
        directories:
          - path: k8s/staging/*
  template:
    spec:
      syncPolicy:
        automated:
          prune: true
          selfHeal: true  # toute dérive manuelle est annulée automatiquement
```

---

### Sprint 2 — Landing Zone : Terraform modules AWS Organizations

**Durée estimée :** 2 semaines | **Coût AWS :** ~5$/mois (permanent)  
**Lacunes adressées :** Landing Zone AWS, Terraform modules custom, SCPs, IAM Identity Center, FinOps posture-toggle

**Objectif :** déployer une Landing Zone AWS complète depuis le management account, avec un coût permanent minimal. Toutes les SCPs sont testées en compte sandbox avant d'être appliquées aux OUs.

**Livrables :**

- Module `aws-organization` — Organizations, OUs (Security / Workloads / Sandbox), comptes enfants + alias Gmail
- Module `aws-scp` — 6 SCPs :
  - `deny-root-usage`
  - `deny-regions-outside-eu` — **en excluant explicitement les services globaux** (`iam`, `route53`, `cloudfront`, `sts`, `support`, `s3` control plane)
  - `require-mfa-for-console`
  - `deny-public-s3`
  - `enforce-cloudtrail`
  - `deny-iam-longterm-keys`
- Module `aws-sso` — IAM Identity Center, permission sets `AdminAccess` (break-glass uniquement) / `DevAccess` / `ReadOnly`
- Module `aws-baseline` — **posture à deux niveaux** via `enable_full_posture` :
  - **Toujours actif (~5$/mois)** : 1 CloudTrail multi-région (management account), AWS Config limité aux règles `required-tags` + `cloudtrail-enabled`, S3 logs, Budget Alert 20$/compte, Cost Anomaly Detection
  - **`enable_full_posture = true` (sessions Sprint 3+, ~+4$/jour)** : GuardDuty sur les 4 comptes, règles AWS Config CIS complètes — activé via `terraform apply -target=module.aws_baseline` en début de session, désactivé en fin de session
- Override MiniStack pour validation locale avant apply réel
- `docs/account-vending.md` — procédure de création d'un nouveau compte
- `docs/scp-global-services.md` — services globaux exclus de `deny-regions-outside-eu`

#### Hors scope — Landing Zone enterprise

Cette Landing Zone couvre les fondamentaux d'une fondation multi-comptes (Organizations, OUs, SCPs, IAM Identity Center, CloudTrail, Config, GuardDuty). Une Landing Zone d'entreprise (type AWS Landing Zone Accelerator) irait plus loin :

| Brique | Apport | Pourquoi hors scope ici |
|---|---|---|
| AWS Control Tower | Account factory, guardrails préconfigurés, dashboard de conformité | Reconstruction manuelle des concepts via Terraform, plus formateur que le produit managé |
| Compte `log-archive` dédié | Logs centralisés, immutables, isolés des comptes workload | Logs conservés dans le compte audit pour limiter le nombre de comptes |
| Compte `network` (Transit Gateway) | Hub-and-spoke, inspection trafic inter-VPC | Un VPC par environnement suffit pour une app mono-service |
| Network Firewall centralisé | Inspection egress (DNS filtering, IDS/IPS) | Coût (~$0.40/h/AZ) disproportionné ; couvert par WAF + Security Groups + NetworkPolicies |
| AWS Audit Manager | Mapping conformité SOC2/ISO27001 | Pas d'exigence de conformité réelle |
| Service Catalog / Account Factory | Provisioning self-service de comptes | `docs/account-vending.md` (procédure manuelle) suffit à 4 comptes |
| AWS Backup cross-account | Politique de backup unifiée multi-comptes | RDS backup natif suffit pour une démo stateless |
| Tag Policies (Organizations) | Enforcement de tags à l'échelle org | Règle AWS Config `required-tags` suffit à ce périmètre |

---

### Sprint 3 — Platform : modules Terraform EKS + réseau + services AWS

**Durée estimée :** 3 semaines | **Coût AWS :** ~3-5$/session  
**Lacunes adressées :** Terraform modules custom avancés, IRSA, Karpenter, CloudFront, WAF, ALB, Gateway API, Cognito, Lambda webhook, RDS, SNS/SQS fan-out, sidecars, init containers, FinOps

**Objectif :** déployer toute l'infrastructure de ShopDemo via des modules Terraform opinionated. Un seul chemin d'auth via Gateway API NGINX. Lambda uniquement pour le webhook paiement async.

**Livrables Terraform :**

- Module `vpc` — subnets publics/privés 3 AZs, NAT Gateway, VPC Flow Logs (vers S3), tags obligatoires, **VPC Endpoints** : `ecr.api`, `ecr.dkr`, `sqs`, `secretsmanager`, `sts` (Interface) + `s3` (Gateway)
- Module `eks-cluster` — EKS + Karpenter (Spot + Graviton, **AMI Amazon Linux 2023**), IRSA, addons managés, KMS encryption, **control plane logs complets** (`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`), **ECR lifecycle policy**
- Module `irsa-role` — rôle IAM + trust policy OIDC + annotation service account automatique
- Module `rds-postgres` — RDS PostgreSQL multi-AZ, instance **Graviton t4g**, backup 7 jours, Secrets Manager, rotation automatique. Post-provisioning : `ansible-playbook rds-setup.yml` crée databases + users least-privilege (cf. Sprint 0)
- Module `sns-fanout` — 2 topics SNS (`commande-créée`, `paiement-confirmé`) + 2 queues SQS abonnées par topic + DLQ + policy IRSA

> **Idempotence — conception explicite** : SQS garantit *at-least-once delivery* — un message peut être livré plusieurs fois (retry réseau, visibility timeout expiré). `service-stock` et `service-notification` implémentent une garde d'idempotence :
> - Chaque message SNS porte un `event_id` (UUID généré par `service-commande`/`lambda-webhook-paiement`) et l'`order_id` métier
> - Table `processed_events (event_id UUID PRIMARY KEY, processed_at TIMESTAMPTZ)` dans la base de chaque consumer
> - Le handler insère `event_id` dans `processed_events` **avant** d'appliquer l'effet métier (décrément stock, log notification), dans la même transaction SQL — un conflit de clé primaire (`ON CONFLICT DO NOTHING` côté Postgres) signale un doublon, le message est acquitté sans ré-appliquer l'effet
> - **DLQ + redrive** : après 3 tentatives (maxReceiveCount), le message part en DLQ. Une alerte `DLQ depth > 0` (Sprint 4) déclenche une investigation manuelle ; la redrive policy SQS permet de renvoyer les messages en DLQ vers la queue principale après correction
> - **Réconciliation** : un job planifié (EventBridge + Lambda, hors chemin critique) compare périodiquement `commandes.statut` (RDS) avec les `processed_events` de `service-stock` pour détecter les divergences stock/commande non résolues par le flux normal
- Module `cloudfront-waf` — distribution CloudFront (origin S3 + ALB), WAF WebACL (`AWSManagedRulesCommonRuleSet`, `AWSManagedRulesSQLiRuleSet`), rate limiting 1000 req/5min, OAC pour S3
- Module `alb` — AWS Load Balancer Controller via Helm
- Module `api-gateway-webhook` — API Gateway AWS + Lambda `lambda-webhook-paiement` (Go) + validation HMAC signature provider + IAM role + CloudWatch logs
- Cognito User Pool + App Client
- External Secrets Operator — synchronise Secrets Manager → Kubernetes `Secret`
- Gitea déployé via Helm. Post-déploiement : `ansible-playbook gitea-setup.yml` crée l'org, les repos et le token bot GitOps (cf. Sprint 0)

> **OS — Ubuntu vs Amazon Linux 2023** : le serveur local et l'EC2 runner bootstrap utilisent Ubuntu 24.04 LTS (distribution la plus documentée pour k3s/Cilium, support large du role `dev-sec.os-hardening`). Les nodes EKS provisionnés par Karpenter utilisent **Amazon Linux 2023** — AMI optimisée AWS, intégration native ECR/IMDSv2/SSM, patches de sécurité plus rapides. Le hardening CIS est appliqué aux deux : Ubuntu via Ansible classique (Sprint 0), AL2023 via `ansible-pull` au boot des nodes (ci-dessous).

**Hardening CIS des nodes EKS (Amazon Linux 2023) :**

```yaml
# karpenter/nodepool-spot.yaml — EC2NodeClass
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
spec:
  amiFamily: AL2023

  # IMDSv2 enforced — ferme la surface SSRF → vol de credentials IAM du node
  metadataOptions:
    httpEndpoint: enabled
    httpTokens: required          # IMDSv1 désactivé
    httpPutResponseHopLimit: 1     # un pod ne peut pas requêter l'IMDS du node via un hop réseau
    httpProtocolIPv6: disabled

  userData: |
    #!/bin/bash
    # ansible-pull — le node se configure lui-même au boot,
    # pas de connexion SSH sortante depuis le control node
    dnf install -y ansible-core
    ansible-pull -U https://gitea.local/org/idp-platform.git \
      ansible/playbooks/harden.yml \
      -i localhost,
```

```hcl
# module eks-cluster — control plane logs complets
enabled_cluster_log_types = [
  "api", "audit", "authenticator", "controllerManager", "scheduler"
]
```

**Livrables Kubernetes :**

Init container sur tous les services avec BDD :
```yaml
initContainers:
  - name: db-migrate
    image: shopdemo/db-migrate@sha256:<digest>
    # attend RDS, applique migrations SQL, container principal démarre après succès
```

Sidecars :
- `sqs-producer-proxy` sur `service-commande` : publie sur SNS, buffer local + retry
- `fluent-bit` sur tous les services : logs structurés → Loki

HPA + PDB sur tous les services stateless :
```yaml
# hpa/service-catalogue.yaml
spec:
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

Karpenter NodePool Spot + Graviton :
```yaml
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          values: ["spot", "on-demand"]
        - key: kubernetes.io/arch
          values: ["arm64", "amd64"]
        - key: node.kubernetes.io/instance-type
          values: ["m7g.large", "m6g.large", "m5.large", "m6i.large"]
```

Topology-aware routing :
```yaml
spec:
  trafficDistribution: PreferClose  # K8s 1.31+ — préfère pods dans la même AZ
```

Gateway API avec validation JWT — mécanisme concret :
- `GatewayClass` + `Gateway` dans `gateway-system` (platform team)
- `HTTPRoute` par service dans `shopdemo` (équipes app)
- **NGINX Gateway Fabric** (implémentation Gateway API de référence côté NGINX) ne valide pas nativement les JWT via la spec Gateway API standard — la validation est déléguée à un `ExternalAuth`/auth-request vers un service d'authentification léger (`jwt-authorizer`, basé sur `njs` ou un petit service Go), déployé une fois dans `gateway-system` plutôt qu'en sidecar par pod
- Configuration de l'authorizer :
  - **Issuer** : `https://cognito-idp.eu-west-1.amazonaws.com/<user-pool-id>`
  - **Audience** : App Client ID Cognito
  - **JWKS** : récupéré depuis `https://cognito-idp.../.well-known/jwks.json`, caché en mémoire (TTL 1h), refresh sur erreur de signature
  - **Clock skew** : tolérance ±60s sur `exp`/`iat`
  - **Claims propagés** : `sub` (user ID) et `email` injectés en headers (`X-User-Sub`, `X-User-Email`) vers le service backend après validation
  - **Routes publiques** : `/api/catalogue` (GET) en lecture est exempté de JWT — `HTTPRoute` séparée sans filtre auth, pour permettre la navigation catalogue sans compte
  - **Routes protégées** : `/api/panier`, `/api/commande`, `/api/paiement`, `/api/catalogue` (POST/PUT/DELETE) — filtre `ExtensionRef` vers l'authorizer sur leurs `HTTPRoute`
- Ce pattern remplace l'oauth2-proxy sidecar par pod : un seul authorizer central, partagé par tous les `HTTPRoute`, plus simple à faire évoluer (rotation JWKS, changement de User Pool) qu'un sidecar dupliqué N fois

---

### Sprint 4 — Observabilité : stack PLG + dashboards ShopDemo

**Durée estimée :** 2 semaines | **Coût AWS :** ~3-5$/session  
**Lacunes adressées :** Loki (alternative ELK), observabilité applicative, cost visibility EKS

**Livrables :**

- `kube-prometheus-stack` — Prometheus Operator, kube-state-metrics, node-exporter
- Alertes avec **runbooks liés** (`runbook_url`) :
  - CPU/mémoire node > 80% → `runbooks/node-pressure.md`
  - Pod en `CrashLoopBackOff` → `runbooks/pod-crashloop.md`
  - Certificat < 30 jours → `runbooks/cert-expiry.md`
  - Latence API > 500ms → `runbooks/api-latency.md`
  - **DLQ depth > 0** → `runbooks/dlq-messages.md`
  - **Karpenter node NotReady** → `runbooks/karpenter-node.md`
- Loki `SingleBinary` + **Fluent Bit DaemonSet** — labels `namespace`, `pod`, `container`, `service`
- Grafana : cluster, ShopDemo métier (commandes/min, latence P50/P95/P99), logs LogQL, alertes Falco, cost overview Kubecost
- **Kubecost** — namespace-level cost breakdown intégré à Prometheus
- `monitoring/docs/elk-vs-plg.md` — comparaison ELK vs PLG
- `monitoring/runbooks/` — runbooks Markdown pour chaque alerte

---

### Sprint 5 — DevSecOps : shift-left complet

**Durée estimée :** 2 semaines | **Coût AWS :** ~3-5$/session  
**Lacunes adressées :** DevSecOps, sécurité Kubernetes, secrets, admission control, threat modeling

**Pre-commit :** `detect-secrets`, `hadolint`, `tfsec`

**Pipeline CI :**
- `GitLeaks` — scan historique Git complet
- `Trivy` — image Docker + IaC Terraform/K8s, bloque si CVE CRITICAL
- `OWASP Dependency-Check` — dépendances Go, bloque si CVE CRITICAL
- **Digest pinning** : `update-gitops-tag` patche avec `image@sha256:<digest>` — Kyverno bloque tout tag non-digest en prod

**Kyverno policies :**
- `runAsNonRoot: true` obligatoire
- `resources.limits` obligatoires
- Images sans digest bloquées en prod
- Labels `app`, `version`, `team` obligatoires
- `hostNetwork`, `hostPID`, `privileged` interdits

**Falco :** règles par défaut + alertes routées vers Grafana

**Secrets management :**
- AWS Secrets Manager pour tous les secrets
- External Secrets Operator → Kubernetes `Secret`
- Rotation automatique credentials RDS

**Threat model (OWASP Threat Dragon) :**
Menaces STRIDE par composant : Cognito, API Gateway, Lambda webhook, services Go, RDS, SNS/SQS. Versionné dans `devsecops/threat-model/shopdemo.dtd`.

---

### Sprint 6 — CI/CD : pipeline GitLab + Components réutilisables

**Durée estimée :** 2 semaines | **Coût AWS :** ~3-5$/session  
**Lacunes adressées :** GitLab Components, pipeline CI avancé, OIDC auth AWS, supply chain SLSA, GitOps bout en bout, upgrade EKS

**Objectif :** pipeline CI/CD complet avec GitLab Components versionnés, authentification AWS via OIDC (zéro clé IAM), builds rootless via Kaniko, supply chain SLSA L2, et répartition des jobs entre shared runners GitLab.com et EC2 runner bootstrap.

> **Répartition des runners** : `terraform apply`/`destroy` du state **workload** (envs/staging, envs/prod) tournent sur les **shared runners GitLab.com** — gratuits (400 min/mois), et hors du cycle de vie qu'ils gèrent (pas de risque de destruction du runner par lui-même). Les jobs nécessitant le réseau privé (`kubectl apply`, accès direct RDS pour debug) tournent sur l'**EC2 runner bootstrap** via le tag `ec2-runner`. Le state **bootstrap** lui-même (EC2 runner, S3 state, OIDC) est appliqué/détruit sur shared runner, manuellement, rarement.

```yaml
# Exemple de répartition par tags
terraform-workload-apply:
  tags: [gitlab-shared]      # state workload — shared runner
  script: [terraform -chdir=platform/terraform/envs/staging apply -auto-approve]

terraform-workload-destroy:
  tags: [gitlab-shared]      # idem — le runner qui détruit n'est jamais celui détruit
  script: [terraform -chdir=platform/terraform/envs/staging destroy -auto-approve]

deploy-shopdemo:
  tags: [ec2-runner]         # kubectl apply — nécessite réseau privé VPC
  script: [kubectl apply -f k8s/staging/]

terraform-bootstrap:
  tags: [gitlab-shared]      # state bootstrap — manuel, rare
  rules:
    - if: $CI_COMMIT_BRANCH == "bootstrap"
      when: manual
```

### Vue d'ensemble du pipeline

```mermaid
flowchart TD
    subgraph COMP["GitLab Components — hébergés sur Gitea"]
        BI["build-image@1.x<br/>Kaniko + digest sha256 + SBOM"]
        SS["scan-security@1.x<br/>Trivy + OWASP + GitLeaks ∥"]
        UG["update-gitops-tag@1.x<br/>patch digest + [skip ci]"]
    end

    subgraph PIPELINE["Pipeline par service ShopDemo"]
        direction LR
        LINT["lint / test<br/>stage 1"] -->|needs| BUILD["build-image<br/>stage 2"]
        BUILD -->|needs| SCAN["scan-security<br/>stage 3"]
        SCAN -->|needs| DEPLOY_S["deploy staging<br/>OIDC → AWS"]
        DEPLOY_S -->|manual gate| DEPLOY_P["deploy prod<br/>protected env + approbation"]
    end

    COMP -.->|include @version fixe| PIPELINE

    DEPLOY_S & DEPLOY_P --> GITOPS["Gitea repo GitOps<br/>patch digest sha256"]
    GITOPS --> ARGO["Argo CD détecte changement<br/>déploie automatiquement"]
```

**Livrables :**

**Component `build-image`** — Kaniko (rootless, pas de `privileged: true`), push ECR, extraction digest sha256, génération SBOM CycloneDX :
```yaml
# ci/components/build-image/template.yml
build-image:
  image:
    name: gcr.io/kaniko-project/executor@sha256:<digest>  # image CI pinnée
    entrypoint: [""]
  script:
    - /kaniko/executor
        --context $CI_PROJECT_DIR
        --dockerfile Dockerfile
        --destination $ECR_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHORT_SHA
        --digest-file /kaniko/digest
    - cat /kaniko/digest > digest.txt   # sha256:abc123...
    # SBOM CycloneDX — talking point supply chain
    - trivy image --format cyclonedx --output sbom.json
        $ECR_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHORT_SHA
  artifacts:
    paths: [digest.txt, sbom.json]
    expire_in: 30 days
```

**Component `scan-security`** — Trivy + OWASP + GitLeaks en parallèle via DAG `needs:`, bloque si CVE CRITICAL :
```yaml
scan-security:
  needs: [build-image]   # DAG — démarre dès build fini, sans attendre les autres jobs
  parallel:
    matrix:
      - SCAN_TYPE: [trivy-image, trivy-iac, owasp-deps, gitleaks]
  script:
    - # dispatch selon $SCAN_TYPE...
  allow_failure: false
  artifacts:
    reports:
      container_scanning: trivy-image.sarif
    paths: ["*.sarif", "*.json"]
    when: always
    expire_in: 30 days
```

**Component `update-gitops-tag`** — token bot Gitea dédié (scope minimal), `[skip ci]` obligatoire, patch via `yq` :
```yaml
update-gitops-tag:
  needs: [scan-security]
  image: mikefarah/yq@sha256:<digest>   # yq pinné par digest
  script:
    - DIGEST=$(cat digest.txt)
    - git clone https://gitops-bot:$GITOPS_TOKEN@gitea.local/org/idp-gitops.git
    - cd idp-gitops
    # yq avec chemin explicite — robuste aux variations d'indentation/structure,
    # contrairement à sed -i sur du YAML
    - yq -i ".image = \"${ECR_REGISTRY}/${SERVICE_NAME}@${DIGEST}\"" \
        k8s/$TARGET_ENV/$SERVICE_NAME/values.yaml
    # validation du YAML généré avant commit
    - helm template k8s/$TARGET_ENV/$SERVICE_NAME | kubeconform -strict -
    - git commit -am "chore: update $SERVICE_NAME digest [skip ci]"
    # ↑ [skip ci] obligatoire — évite la boucle infinie CI → push → CI
    - git push origin $TARGET_BRANCH
  variables:
    GITOPS_TOKEN: $GITOPS_BOT_TOKEN   # variable protected + masked, scope repo GitOps uniquement
```

> **Pourquoi `yq` et non `sed`** : `sed -i` sur du YAML est fragile dès que l'indentation, les commentaires ou la structure changent — un match approximatif peut patcher la mauvaise ligne ou produire un YAML invalide sans erreur visible. `yq` cible le chemin exact (`.image`) indépendamment du formatage, et `kubeconform` valide le rendu Helm avant le commit.

**Auth AWS via OIDC** — module Terraform `gitlab-oidc` + `id_tokens:` dans chaque component déployant :
```yaml
# Dans les components build-image et update-gitops-tag
id_tokens:
  AWS_OIDC_TOKEN:
    aud: "https://sts.amazonaws.com"
script:
  - export $(aws sts assume-role-with-web-identity
      --role-arn "$AWS_ROLE_ARN"
      --role-session-name "gitlab-ci-$CI_JOB_ID"
      --web-identity-token "$AWS_OIDC_TOKEN"
      --duration-seconds 3600
      --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]'
      --output text | awk '{print "AWS_ACCESS_KEY_ID="$1"\nAWS_SECRET_ACCESS_KEY="$2"\nAWS_SESSION_TOKEN="$3}')
  - aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REGISTRY
```

Module Terraform `gitlab-oidc` — provider OIDC + rôle IAM scopé par projet et branche :
```hcl
resource "aws_iam_openid_connect_provider" "gitlab" {
  url             = "https://gitlab.com"
  client_id_list  = ["https://sts.amazonaws.com"]
  thumbprint_list = ["b3dd7606d2b5a8b4a13771dbecc9ee1cecafa38a"]
}

resource "aws_iam_role" "gitlab_ci_staging" {
  max_session_duration = 3600   # 1h — durée max des credentials éphémères

  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.gitlab.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "gitlab.com:aud" = "https://sts.amazonaws.com" }
        StringLike   = {
          # ✅ Scopé projet + branche — aucun autre projet ne peut assumer ce rôle
          "gitlab.com:sub" = "project_path:monorg/idp-platform:ref_type:branch:ref:staging"
        }
      }
    }]
  })
}
```

> **Thumbprint statique** : AWS valide le certificat TLS racine de l'IdP via ce thumbprint SHA-1. Il change rarement (changement d'autorité de certification racine de gitlab.com), mais **change quand même** — sans rotation automatique, l'OIDC casse silencieusement à la prochaine rotation de certificat root. À documenter dans `platform/docs/oidc-maintenance.md` : vérification annuelle via `openssl s_client -connect gitlab.com:443 | openssl x509 -fingerprint -sha1 -noout`, ou utiliser le thumbprint générique AWS pour les IdP publics (`aws_iam_openid_connect_provider` sans `thumbprint_list` depuis le provider AWS récent, qui dérive automatiquement le thumbprint).

**Permissions IAM minimales par Component** — chaque rôle OIDC (staging/prod) n'a que les permissions nécessaires à son Component :

| Component | Action IAM | Ressource scopée |
|---|---|---|
| `build-image` | `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload` | `arn:aws:ecr:eu-west-1:<account>:repository/shopdemo/*` |
| `update-gitops-tag` | *(aucune permission AWS — push Git uniquement via `GITOPS_TOKEN`)* | — |
| `deploy-frontend` | `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` ; `cloudfront:CreateInvalidation` | bucket `shopdemo-frontend-$ENV` ; distribution CloudFront du projet |
| `terraform-workload-apply/destroy` | permissions larges (création VPC/EKS/RDS/...) | scopées par tag `Project=idp-platform` via condition IAM `aws:RequestTag` quand le service le supporte |
| `deploy-shopdemo` (EC2 runner, kubectl) | `eks:DescribeCluster`, `eks:AccessKubernetesApi` | cluster EKS staging, via EKS Access Entry namespace `shopdemo` (ci-dessous) |

Un rôle IAM distinct par Component plutôt qu'un rôle unique partagé : si le token OIDC d'un job `build-image` fuite, l'attaquant peut pousser une image sur ECR mais ne peut ni toucher Terraform, ni le bucket S3 frontend, ni le cluster EKS.

EKS Access Entries — accès pipeline scopé au namespace `shopdemo` uniquement :
```hcl
resource "aws_eks_access_policy_association" "gitlab_ci" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.gitlab_ci_staging.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
  access_scope {
    type       = "namespace"
    namespaces = ["shopdemo"]   # pas d'accès au reste du cluster
  }
}
```

**Protected Environment prod** (Settings > CI/CD > Environments > production) :
- Déploiement prod : `when: manual` + approbation obligatoire d'un mainteneur ≠ déclencheur
- `rules: changes:` par service dans le monorepo — évite de rebuilder tous les services si seul `service-catalogue` a changé

**Pipeline Terraform :**
- `fmt` + `validate` + `plan` sur chaque PR
- `apply` automatique sur merge (staging) ou tag semver (prod)

**Pipeline frontend :**
- Build fichiers statiques
- `aws s3 sync` vers S3
- Invalidation CloudFront `aws cloudfront create-invalidation`

**Procédure upgrade EKS** (`platform/docs/eks-upgrade.md`) :

EKS est managé pour le control plane — AWS gère HA et patches. Nodes, addons et composants tiers restent sous responsabilité de l'opérateur.

```bash
kubent                    # 1. détecter APIs dépréciées dans les manifests
terraform apply           # 2. upgrader control plane (eks_version = "1.32")
terraform apply           # 3. upgrader addons managés (coredns, kube-proxy, vpc-cni, ebs-csi)
# 4. nouveau NodePool Karpenter avec nouvel amiFamily
#    taint l'ancien NodePool → Karpenter drains et consolide → zero-downtime
# 5. upgrader Karpenter, Cilium (chaining), Argo CD — vérifier compatibility matrix
# 6. smoke tests staging → prod
```

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
| CNI Kubernetes (Cilium) | Sprint 1 | Déploiement, NetworkPolicy, Hubble, chaining vs replacement |
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
