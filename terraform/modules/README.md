# Modules Terraform

Modules internes du projet, appelés par les states racine de [`../bootstrap/`](../bootstrap/) et, à partir du Sprint 3, de [`../envs/`](../envs/).

Vide en `S2-T1` : la structure est posée avant que le premier module existe, exactement comme `gitops/` avait été posé avant l'installation d'Argo CD.

Modules attendus dans le Sprint 2 :

| Module | Tâche | Rôle |
|---|---|---|
| `aws-organization` | `S2-T3` | Organization, OUs, comptes enfants |
| `aws-scp` | `S2-T4` | Six SCPs, éprouvées en compte `sandbox` avant attachement |
| `aws-sso` | `S2-T5` | IAM Identity Center et permission sets |
| `aws-baseline` | `S2-T6` | CloudTrail, Config, budgets, interrupteur `enable_full_posture` |

Conventions : chaque module expose `variables.tf`, `outputs.tf`, `versions.tf` et un `README.md` décrivant ses entrées, ses sorties et ce qu'il ne fait volontairement pas.
