# AWS Organization

[Topologie](#topologie) · [Interface](#interface) · [Validation](#validation) · [Securite et cycle de vie](#securite-et-cycle-de-vie)

Module permanent appele par `terraform/bootstrap/`, conforme a [S2-T3](../../../docs/sprints/sprint-2-landing-zone.md#s2-t3---module-aws-organization). Creation AWS validee par le proprietaire : huit ajouts, plan suivant sans changement (code 0), rattachements aux OUs confirmes.

## Topologie

| Cle Terraform | Nom AWS | OU |
|---|---|---|
| `security_audit` | `security-audit` | Security |
| `workload_staging` | `workload-staging` | Workloads |
| `workload_prod` | `workload-prod` | Workloads |
| `sandbox` | `sandbox` | Sandbox |

`feature_set = "ALL"` active toutes les fonctionnalites Organizations. `enabled_policy_types = ["SERVICE_CONTROL_POLICY"]` declare explicitement l'activation du type SCP, effectuee initialement en console pendant S2-T4. `aws_service_access_principals = ["sso.amazonaws.com"]` conserve l'acces de confiance ajoute lors de l'activation IAM Identity Center ; sans cette declaration, Terraform le retirerait comme une derive et rendrait l'instance inaccessible. AWS peut installer ses policies par defaut : ne pas confondre celles-ci avec les SCP restrictives du projet prevues en S2-T4.

## Interface

Entree obligatoire : `account_emails`, map sensible avec exactement les quatre cles ci-dessus. Les valeurs doivent etre des adresses distinctes, accessibles, non deja associees a un compte AWS. Le format et l'unicite sont controles ; leur disponibilite chez AWS et la reception des messages ne peuvent pas etre prouvees par ces validations.

Sorties : `organization_id`, `root_id`, `ou_ids` (cles `security`, `workloads`, `sandbox`) et `account_ids` (sensible). Le provider est herite du bootstrap, avec ses tags et son garde-fou de compte.

Le fichier [`terraform.tfvars.example`](../../bootstrap/terraform.tfvars.example) montre les entrees. Renseigner les valeurs reelles uniquement dans `terraform/bootstrap/terraform.tfvars`, ignore par Git. `sensitive` masque l'affichage, mais ne retire pas les emails du state ou d'un plan sauvegarde.

## Validation

Depuis la racine du depot, tests sans appel AWS :

```bash
terraform -chdir=terraform/modules/aws-organization init -backend=false -lockfile=readonly
terraform -chdir=terraform/modules/aws-organization test
terraform -chdir=terraform/bootstrap validate
tflint --chdir=terraform/bootstrap --config="$(pwd)/terraform/.tflint.hcl"
```

Le lock du module fixe la meme version de provider que le bootstrap pour les tests autonomes. Le lock du root reste celui utilise lors du deploiement.

Apres preparation des emails locaux, produire le plan reel depuis le bootstrap :

```bash
cd terraform/bootstrap
terraform init -backend-config=backend.hcl -lockfile=readonly
terraform plan -input=false -out=tfplan
terraform show -no-color tfplan
```

Au premier deploiement uniquement, attendu : huit ajouts (une Organization, trois OUs, quatre comptes), aucune modification ni suppression du backend S3. Verifier chaque nom, rattachement et email local avant tout apply. Les emails sont masques dans le plan texte : les comparer avec les variables locales dans une session privee. Le plan binaire contient des donnees sensibles, reste ignore par Git et ne doit pas etre partage. Rechercher toute suppression, tout remplacement et toute modification inattendue ; en cas de divergence, interrompre la preparation de l'apply et diagnostiquer.

Le plan ne prouve ni la disponibilite des emails ni les quotas de creation de comptes. Ces controles ont ete realises par le proprietaire en S2-T3. Apres creation, un plan sans derive doit proposer zero changement ; ne pas reutiliser le plan initial deja applique.

## Securite et cycle de vie

`prevent_destroy` protege Organization, OUs et comptes tant que ces blocs existent dans la configuration. Retirer un bloc retire aussi son garde-fou : ce n'est pas une protection cote AWS. `close_on_deletion = false` n'autorise aucune fermeture automatique et ne remplace pas cette protection.

Le role d'administration initial des nouveaux comptes suit le comportement AWS par defaut. Son acces depuis le management account doit etre compris avant creation ; Identity Center et les permissions fines seront traites en S2-T5. Aucun workload payant n'est ajoute par ce module ; le backend S3 existant conserve ses frais de stockage et de requetes.

Avant apply, rollback : retirer les changements de configuration non appliques. Apres creation, aucun nettoyage automatique : conserver les fondations et traiter toute sortie ou fermeture de compte comme une operation distincte. Ne pas utiliser `terraform destroy` pour terminer une session workload.

Reference : [ressource Organizations Account du provider AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account).
