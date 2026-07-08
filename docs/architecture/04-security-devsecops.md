# Security And DevSecOps

[Retour a `ARCHITECTURE.md`](../../ARCHITECTURE.md)

## Vue DevSecOps - shift-left

<p align="center"><img src="../diagrams/devsecops-shift-left.svg" alt="DevSecOps shift-left" width="850"></p>

> 📊 **Diagramme interactif** : [`../diagrams/devsecops-shift-left.html`](../diagrams/devsecops-shift-left.html).

La defense en profondeur est organisee sur quatre couches :

- **poste local** : `detect-secrets`, `hadolint`, `tfsec` ;
- **CI** : `GitLeaks`, `Trivy`, `OWASP Dependency-Check` ;
- **runtime EKS** : `Kyverno`, `Falco`, `Cilium`, `ESO` ;
- **posture AWS** : `Security Hub`, `AWS Config`, `SCPs`, detection d'anomalies de cout.

## Hardening local vs cloud

Le hardening local reste volontairement minimal et non intrusif : activation
prudente de `unattended-upgrades`, verification des permissions sur quelques
fichiers sensibles (`~/.kube`, `~/.aws`) et confirmation que les services clefs
journalisent via `journald`.

Ce choix est assume pour preserver la stabilite du lab local et concentrer
l'effort de durcissement exhaustif sur les futures cibles cloud, beaucoup plus
representatives de l'architecture finale.

Pour les futurs sprints cloud, la documentation de hardening devra couvrir au
minimum les couches suivantes :

- **OS et compute** : baseline CIS, patching, reduction de surface d'attaque,
  acces admin, `journald` / audit, IMDSv2 ;
- **Kubernetes et EKS** : bootstrap node, kubelet/runtime, pods non root,
  `seccomp`, capabilities, logs control plane, segmentation reseau ;
- **IAM et identite** : `IRSA`, moindre privilege, separation des roles CI /
  runtime / ops, absence de credentials statiques ;
- **reseau** : subnets, Security Groups, endpoints prives, egress maitrise,
  exposition Internet minimale ;
- **secrets et donnees** : `Secrets Manager`, `ESO`, rotation, chiffrement KMS,
  droits d'acces et retention ;
- **detection et posture** : `CloudTrail`, `AWS Config`, `GuardDuty`, alertes,
  preuves de validation et risques residuels ;
- **supply chain CI/CD** : OIDC GitLab vers AWS, pinning par digest, SBOM,
  scans de securite, controles avant deploiement GitOps.

## Controles pod et identite

Les controles autour des workloads incluent :

- `runAsNonRoot` et hygiene de pod via `Kyverno` ;
- `resources` explicites et labels obligatoires ;
- projection des secrets via `External Secrets Operator` ;
- identite AWS par `IRSA`, pas de credentials statiques embarques.

## Posture AWS

La posture cloud n'est pas presentee comme "enterprise grade" permanente. Le projet accepte :

- un **posture toggle** hors session pour contenir le cout ;
- une validation finale sur AWS reel pour les sujets les plus sensibles ;
- une explication explicite des risques residuels.
