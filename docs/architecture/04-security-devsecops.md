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
