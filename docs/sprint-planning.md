# Planning des sprints — IDP Platform

> Détail des objectifs, livrables et extraits techniques par sprint. La conception cible reste [`ARCHITECTURE.md`](../ARCHITECTURE.md) ; ce document ne fait qu'expliciter comment chaque sprint construit cette cible. Le suivi d'avancement (état, blocages, preuves) vit dans `docs/sprints/sprint-N-*.md`, indexé depuis la table de suivi du [`README.md`](../README.md#où-en-est-le-projet) racine.

### Sprint 0 — Ansible : provisioning local + fondations bootstrap

**Durée estimée :** 2 semaines | **Coût AWS :** 0$ (local) + ~5$/mois (bootstrap EC2, dès activation)  
**Lacunes adressées :** Ansible, idempotence, Molecule, dynamic inventory, frontière Terraform/Ansible

**Objectif :** rendre le serveur Ubuntu entièrement reproductible via un seul playbook, ET poser la frontière Terraform (provisionne) / Ansible (configure) qui sera réutilisée sur l'EC2 runner et RDS dans les sprints suivants.

**Molecule** crée un container Docker, joue le role dedans, vérifie le résultat, puis vérifie l'idempotence en rejouant le role une seconde fois — un role correct ne doit rien modifier au second passage.

**Livrables — serveur local :**

- Role `k3s-install` — k3s sans CNI par défaut, kubeconfig configuré
- Role `cilium-setup` — Cilium via Helm, Hubble activé (mode replacement sur k3s)
- Role `ministack-setup` — MiniStack + profil AWS CLI `ministack` (Docker prerequis)
- Role `cloudflare-tunnel` — cloudflared installé, sous-domaines `argocd.` et `grafana.` — exposition sans port entrant
- Role `gitlab-runner` — runner enregistré en mode Docker executor
- Role `node-hardening` — baseline CIS via `dev-sec.os-hardening` (Ubuntu)
- Playbook `bootstrap.yml` — orchestre tous les roles, idempotent
- Playbook `teardown.yml` — remet le serveur à zéro
- Tests Molecule sur chaque role : converge → idempotency → verify
- Inventory `aws_ec2.yml` — dynamic inventory, couvrira l'EC2 runner et les nodes EKS

**Livrables — frontière Terraform/Ansible (préparation Sprint 3) :**

- Playbook `runner-setup.yml` — configure l'EC2 runner bootstrap après sa création par Terraform (Docker, gitlab-runner, enregistrement token)
- Playbook `rds-setup.yml` — crée les databases et users PostgreSQL avec privilèges least-privilege, une fois RDS provisionné par Terraform

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

### Sprint 1 — Argo CD et base GitOps locale

**Durée estimée :** 2 semaines | **Coût AWS :** 0$  
**Lacunes adressées :** Argo CD multi-env, GitOps branching strategy

**Objectif :** Argo CD déployant sur deux environnements depuis des sources Git distinctes, au-dessus du cluster k3s + Cilium déjà livré en Sprint 0 (roles `k3s-install` et `cilium-setup`).

**Livrables :**

- NetworkPolicies : default-deny ingress/egress par namespace, allow explicite inter-services (s'appuient sur Cilium installé en Sprint 0)
- Argo CD + `ApplicationSet` staging (watch branche `staging`, déploiement auto sur merge)
- Argo CD + `ApplicationSet` prod (watch tags `v*.*.*`, déploiement auto sur tag semver)
- **Sync waves** : CRDs (wave -5) → ExternalSecrets (wave -2) → Deployments (wave 0) → HTTPRoutes (wave 2)
- `docker-compose.yml` pour le dev local sans Kubernetes

```yaml
# applicationset-staging.yaml — extrait
spec:
  generators:
    - git:
        repoURL: https://gitlab.com/shopdemo/shopdemo-gitops.git
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
    ansible-pull -U https://gitlab.com/shopdemo/shopdemo-platform.git \
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

<p align="center"><img src="diagrams/pipeline-cicd-overview.svg" alt="Vue d'ensemble du pipeline CI/CD" width="850"></p>

> 📊 **Diagramme interactif** : [`diagrams/pipeline-cicd-overview.html`](diagrams/pipeline-cicd-overview.html) (version archify — export PNG/SVG).

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

**Component `update-gitops-tag`** — token GitOps dédié (scope minimal), `[skip ci]` obligatoire, patch via `yq` :
```yaml
update-gitops-tag:
  needs: [scan-security]
  image: mikefarah/yq@sha256:<digest>   # yq pinné par digest
  script:
    - DIGEST=$(cat digest.txt)
    - git clone https://gitops-bot:$GITOPS_TOKEN@gitlab.com/shopdemo/shopdemo-gitops.git
    - cd shopdemo-gitops
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
