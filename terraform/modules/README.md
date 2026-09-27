# Modules Terraform

Modules internes du projet, appelés par les states racine de [`../bootstrap/`](../bootstrap/) et, à partir du Sprint 3, de [`../envs/`](../envs/).

Le module [`aws-organization`](aws-organization/README.md) est livre en `S2-T3`. Creation AWS, convergence et rattachements valides par le proprietaire.

Le module [`aws-scp`](aws-scp/README.md) gere les six SCPs et leurs attachements au seul compte sandbox. Le lot complet est deploye ; la policy regionale et la protection S3 ont une preuve d'effet AWS, les autres preuves restent a produire.

Le module [`aws-sso`](aws-sso/README.md) gere les groupes, permission sets et affectations IAM Identity Center de S2-T5. Il est deploye avec dix-neuf ajouts ; l'utilisateur, la matrice du portail et la difference fonctionnelle entre `DevAccess` et `ReadOnly` sont valides.

Le module [`aws-baseline`](aws-baseline/README.md) gere CloudTrail, AWS Config, les controles de cout et la posture complete optionnelle de S2-T6. Le socle permanent est deploye ; ses preuves fonctionnelles restent a produire. Les deux branches du toggle sont validees localement.

Modules attendus dans le Sprint 2 :

| Module | Tâche | Rôle |
|---|---|---|
| `aws-organization` | `S2-T3` | Organization, OUs, comptes enfants |
| `aws-scp` | `S2-T4` | Six SCPs, éprouvées en compte `sandbox` avant attachement |
| `aws-sso` | `S2-T5` | IAM Identity Center et permission sets |
| `aws-baseline` | `S2-T6` | CloudTrail, Config, budgets, interrupteur `enable_full_posture` |

Conventions : chaque module expose `variables.tf`, `outputs.tf`, `versions.tf` et un `README.md` décrivant ses entrées, ses sorties et ce qu'il ne fait volontairement pas.
