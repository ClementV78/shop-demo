# Terraform

[Structure](#structure) · [Conventions](#conventions) · [Validation](#validation) · [Ce qui n'est pas ici](#ce-qui-nest-pas-ici)

Infrastructure AWS du projet, posée au Sprint 2. La conception cible vit dans [`ARCHITECTURE.md`](../ARCHITECTURE.md) et le suivi dans [`docs/sprints/sprint-2-landing-zone.md`](../docs/sprints/sprint-2-landing-zone.md).

## Structure

```text
terraform/
├── bootstrap/   state permanent : Organization, SCPs, Identity Center, backend, rôle OIDC
├── envs/        state éphémère : VPC, EKS, RDS, à partir du Sprint 3
└── modules/     modules internes, appelés par les states racine
```

Deux states séparés, jamais un seul, conformément à [`ADR-003`](../docs/adr/ADR-003-separate-bootstrap-and-workload-states.md). Le state `bootstrap` héberge le bucket S3 qui stocke le state `workload`. Réunis, un `terraform destroy` du workload détruirait le backend dont il a besoin pour s'exécuter.

## Conventions

**Région** : `eu-west-1`. Une validation sur la variable `aws_region` refuse toute région hors d'Europe, par cohérence avec la SCP `deny-regions-outside-eu` livrée en `S2-T4`.

**Nommage** : `<project>-<environment>-<composant>`, exposé par le local `name_prefix`. Les ressources à nom globalement unique, les buckets S3 en particulier, y ajoutent l'identifiant de compte.

**Tags** : appliqués automatiquement par `default_tags` sur le provider, jamais recopiés ressource par ressource.

| Tag | Valeur | Usage |
|---|---|---|
| `Project` | `shopdemo` | Attribution des coûts dans Cost Explorer |
| `Environment` | `bootstrap`, `staging`, `prod`, `sandbox` | Séparation des états et des coûts |
| `Owner` | valeur générique | Jamais d'information personnelle versionnée |
| `ManagedBy` | `terraform` | Distingue le géré du créé à la main |
| `Sprint` | `S2` | Traçabilité pédagogique propre à ce dépôt |

La règle AWS Config `required-tags` livrée en `S2-T6` s'appuie sur ces clés. Un tag ajouté ici doit l'être aussi là-bas.

**Versions** : `required_version` et les providers sont épinglés. Le fichier `.terraform.lock.hcl` est **committé volontairement** : il fige les empreintes des providers et garantit que la CI installe exactement les mêmes binaires que le poste local. C'est le seul fichier `.terraform*` qui entre dans Git.

**Secrets et identifiants** : aucun dans le dépôt. Les `*.tfvars` et `backend.hcl` sont ignorés par Git, seuls leurs `.example` sans valeur réelle sont versionnés. Ni l'identifiant du compte AWS, ni les emails des comptes enfants n'entrent dans le dépôt.

**Deux clients AWS, pas un** : le bloc `provider` et le bloc `backend` résolvent leurs credentials **indépendamment**. Le garde-fou `allowed_account_ids` du provider ne protège donc pas le backend, et un `profile` défini pour l'un ne vaut pas pour l'autre. C'est pour cette raison que `backend.hcl` porte son propre `profile`. Une migration de state a échoué sur un `403` avant que ce soit compris.

## Validation

Depuis `S2-T2`, le state vit dans S3 et l'initialisation a besoin du fichier de configuration du backend :

```bash
cd terraform/bootstrap
terraform init -backend-config=backend.hcl
terraform plan
```

`backend.hcl` n'est pas versionné parce que le nom du bucket contient l'identifiant du compte. Copier [`bootstrap/backend.hcl.example`](bootstrap/backend.hcl.example) et le renseigner. Idem pour `terraform.tfvars`, à partir de son `.example`.

Pour les validations qui ne doivent toucher ni AWS ni le state :

```bash
terraform fmt -recursive -check terraform/
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap validate
tflint --chdir=terraform/bootstrap --config="$(pwd)/terraform/.tflint.hcl"
```

`init -backend=false` télécharge les providers sans configurer de backend. Attention, il écrase la configuration de backend locale : relancer `init -backend-config=backend.hcl` ensuite pour retrouver le state distant.

Pour vérifier qu'un rejeu ne change rien, l'équivalent du `changed=0` d'Ansible :

```bash
terraform -chdir=terraform/bootstrap plan -detailed-exitcode   # 0 = aucun écart, 2 = écart
```

Le lint AWS demande une initialisation des plugins la première fois :

```bash
tflint --init --config="$(pwd)/terraform/.tflint.hcl"
```

## Ce qui n'est pas ici

État au 2026-09-10 : `S2-T1` a posé la structure sans créer de ressource, et `S2-T2` a livré le bucket de state, chiffré, versionné et verrouillé par fichier S3 natif.

N'existent pas encore : l'Organization et les comptes (`S2-T3`), les SCPs (`S2-T4`), Identity Center (`S2-T5`), la baseline de posture (`S2-T6`) et le rôle OIDC GitLab (`S2-T7`).

L'EC2 runner `bootstrap` reste hors périmètre du Sprint 2 : il n'a d'utilité qu'avec le VPC du Sprint 3 et coûterait une instance permanente d'ici là.
