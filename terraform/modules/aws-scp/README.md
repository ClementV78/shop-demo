# AWS SCP

[Etat](#etat) · [Structure](#structure) · [Validation](#validation) · [Deploiement progressif](#deploiement-progressif) · [Lot sandbox complet](#lot-sandbox-complet)

## Etat

S2-T4 en cours : les six SCPs et leurs attachements sont deployes sur le seul compte sandbox. La policy regionale a ete validee avant le lot groupe ; le proprietaire confirme ensuite l'apply du lot des cinq autres SCPs et de la protection S3 du compte. L'effet S3 est verifie par un refus explicite SCP lors d'une reecriture sure des quatre valeurs a `true`. La policy MFA corrigee pour permettre l'auto-enrolement selon le modele AWS a egalement ete appliquee par le proprietaire. Les autres preuves AWS du lot restent a produire. Les [exceptions globales et limites](../../../docs/scp-global-services.md) doivent etre resolues avant extension aux OUs utiles.

## Structure

- `policies/deny-regions-outside-eu.json` : JSON lisible, region `eu-*`, exceptions globales explicites.
- `main.tf` : cree les six policies `SERVICE_CONTROL_POLICY`, avec JSON compacte. Tags herites du provider bootstrap.
- `variables.tf` : aucune entree pour cette premiere etape, aucun compte ou OU cible.
- `outputs.tf` : expose les six identifiants pour les attachements geres par le root.
- `tests/` : contrat Terraform avec provider simule et matrice locale de requetes.

Le root `terraform/bootstrap/scp.tf` appelle ce module apres le module Organization, qui active le type SCP. Il relie ensuite la sortie de policy a `module.organization.account_ids["sandbox"]` dans `aws_organizations_policy_attachment.regional_sandbox`. Aucun nouveau provider configure dans le module enfant.

## Validation

Depuis la racine du depot, controles sans creation AWS :

```bash
terraform -chdir=terraform/modules/aws-scp init -backend=false -lockfile=readonly
terraform -chdir=terraform/modules/aws-scp validate
terraform -chdir=terraform/modules/aws-scp test
python3 terraform/modules/aws-scp/tests/test_region_policy.py
python3 terraform/modules/aws-scp/tests/test_guardrails.py
```

Le test Python couvre quatorze requetes sur la seule regle de refus (EC2/RDS/S3 regionaux, exceptions IAM/STS/CloudFront/Route 53 et dependances edge encore bloquees). Il ne simule pas l'evaluation IAM complete. Seuls les tests reels en sandbox prouveront le comportement AWS.

## Deploiement progressif

Le proprietaire execute depuis `terraform/bootstrap` :

```bash
terraform init -backend-config=backend.hcl -lockfile=readonly
terraform plan -input=false -detailed-exitcode -out=tfplan
```

Le deploiement initial a cree la policy regionale et son attachement ensemble : deux ajouts. Le lot suivant proposait onze ajouts, aucune modification ni suppression : cinq policies, cinq attachements et la configuration S3 Block Public Access du compte sandbox. Le proprietaire confirme avoir applique ce plan. Tout changement ulterieur doit etre explique avant apply. Les plans et apply AWS sont executes par le proprietaire.

La correction d'auto-enrolement MFA a produit la modification en place attendue de `module.scp.aws_organizations_policy.require_mfa_for_console`, puis le proprietaire a confirme son apply.

Les controles de reference avant attachement sont confirmes par le proprietaire : EC2 Instances en Irlande et Virginie du Nord, IAM Roles et liste CloudFront accessibles. Apres attachement, seule la consultation EC2 hors Europe doit etre refusee parmi ces controles. Ne creer aucune instance ou distribution pour ce test. La propagation peut demander un delai.

Rollback de l'attachement : depuis le management, retirer uniquement le bloc `aws_organizations_policy_attachment.regional_sandbox` du root Terraform et relire le plan (une suppression d'attachement seulement). En cas de blocage urgent, detacher uniquement cette policy via Organizations, puis realigner Terraform avant tout apply pour eviter de la rattacher. Ne pas desactiver toutes les SCPs et ne pas retirer `FullAWSAccess`.

A ce stade, aucun workload ni ressource facturee a l'heure n'est ajoute. Le bootstrap S3 existant conserve ses frais usuels. La suppression d'une policy devenue inutile doit etre precedee de la verification de ses cibles.

## Lot sandbox complet

| Policy | Effet exact | Limite |
|---|---|---|
| `deny-root-usage` | Refuse les actions soumises aux SCPs lorsque `aws:PrincipalArn` designe le root d'un compte membre | Ne supprime pas le root et ne bloque pas la page de connexion ; exemptions AWS des SCPs toujours applicables |
| `deny-iam-longterm-keys` | Refuse `iam:CreateAccessKey` | Aucune suppression des cles existantes ; roles et sessions STS preserves |
| `require-mfa-for-console` | Refuse les actions directes d'un utilisateur IAM avec contexte MFA absent ou faux, sauf les appels necessaires a l'enrolement MFA et a `GetSessionToken` | Le nom historique est conserve, mais la regle couvre aussi les appels API avec cles permanentes. Les roles sont exclus ; leur MFA doit etre geree a la source, notamment Identity Center |
| `deny-public-s3` | Fige le Block Public Access du compte apres activation des quatre protections | La SCP seule ne suffit pas : elle depend du reglage de compte. Les policies privees OAC restent possibles |
| `enforce-cloudtrail` | Refuse `StopLogging` et `DeleteTrail` | Ne cree aucun trail, ne protege pas les selecteurs, le bucket de logs, KMS ou CloudTrail Lake ; baseline complete en S2-T6 |

`aws.sandbox` utilise les credentials du profil management pour assumer `OrganizationAccountAccessRole`, avec `allowed_account_ids` limite au compte sandbox. Il configure uniquement `aws_s3_account_public_access_block.sandbox`. Ce reglage global ne cree aucun bucket. Les attachements restent geres avec le provider management. L'attachement S3 depend explicitement de l'activation des quatre protections pour eviter de figer un etat permissif ; le reglage porte `prevent_destroy`.

La SCP MFA combine deux conditions : identite IAM user ET MFA absente/fausse. Elle suit le modele AWS `Deny` avec `NotAction` : sans MFA, seuls `CreateVirtualMFADevice`, `EnableMFADevice`, `GetUser`, les actions de consultation/resynchronisation MFA et `GetSessionToken` echappent au refus. Ces exceptions n'accordent aucun droit ; une policy IAM distincte doit autoriser l'utilisateur a gerer uniquement son propre dispositif. La suppression d'un dispositif reste refusee sans MFA pour eviter le contournement du controle. Cela ne transforme pas une session de role en session avec MFA et ne garantit pas la MFA des federations. La session `admin1` du management n'est pas soumise a ces SCPs.

La restriction S3 s'applique a tous les buckets sandbox existants et futurs. Aucun besoin de bucket public n'est prevu pour ce compte. L'API de suppression du Block Public Access au niveau compte utilise aussi la permission `s3:PutAccountPublicAccessBlock`. Apres attachement, modifier ce reglage via le role sandbox est bloque, y compris via Terraform : detacher d'abord la SCP S3 depuis le management si une reparation devient necessaire. Ne jamais desactiver le blocage public pour un simple test.

### Preuves attendues et limites de test

Le lot peut etre deploye ensemble, mais chaque effet doit etre verifie separement. Les tests locaux ne sont pas une preuve de refus AWS. Les controles initiaux deja prouves portent uniquement sur la policy regionale.

| Controle | Verification a conduire | Etat |
|---|---|---|
| Acces administrateur | Switch role, IAM Roles, EC2 Irlande et CloudFront restent accessibles | A refaire apres le lot |
| Region | EC2 Virginie refuse | A refaire apres le lot |
| S3 | Quatre protections a true ; reecriture du meme reglage true refusee explicitement par SCP | Verifie par le proprietaire : profil nomme assumant `OrganizationAccountAccessRole`, valeurs maintenues a true, refus explicite SCP |
| Cles IAM | `CreateAccessKey` refuse depuis le role sur un utilisateur de test sans permissions | A preparer ; pas de secret en sortie partagee, utilisateur et eventuelle cle de reference a nettoyer |
| MFA | Meme lecture autorisee via utilisateur IAM avec MFA, refusee sans MFA ; role preserve | A preparer avec identite de test et reference avant restriction, sans confondre refus IAM et SCP |
| Root | Action de lecture du root membre refusee explicitement par SCP | Non verifie ; ne pas activer ou recuperer des credentials root uniquement pour embellir une preuve |
| CloudTrail | Arret/suppression refuses sur un trail de test appartenant a sandbox | Non verifie en l'absence de trail ; un nom inexistant ou un trail organisationnel non modifiable ne prouve pas le controle |

Pour une mesure avant/apres non encore preparee, organiser un detachement temporaire cible depuis le management, puis retablir l'attachement Terraform. Ne pas le faire implicitement pendant l'apply groupe. Ne pas creer de trail payant ni d'identite de test sans expliquer d'abord le protocole, le nettoyage et les couts. Tant que ces preuves manquent, S2-T4 reste en cours et les SCPs ne sont pas propagees aux OUs utiles.

Rollback du lot : retirer uniquement les cinq nouveaux blocs d'attachement dans `terraform/bootstrap/scp.tf`, puis verifier un plan de cinq suppressions d'attachement. Conserver les policies, la protection S3 a true et la SCP regionale. En urgence, detacher les policies concernees depuis le management puis realigner le code pour eviter un rattachement involontaire. Une suppression d'attachement S3 ne supprime pas la protection publique du compte.

Sources : [contexte MFA IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html#condition-keys-multifactorauthpresent), [modele AWS d'auto-enrolement MFA](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_aws_my-sec-creds-self-manage-mfa-only.html), [protection publique S3 de compte](https://docs.aws.amazon.com/AmazonS3/latest/userguide/configuring-block-public-access-account.html), [StopLogging](https://docs.aws.amazon.com/awscloudtrail/latest/APIReference/API_StopLogging.html), [portee des SCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html).
