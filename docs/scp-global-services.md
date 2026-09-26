# Exceptions globales de la SCP regionale

[Perimetre](#perimetre) · [Exceptions](#exceptions) · [Limites](#limites) · [Sources](#sources)

## Perimetre

`deny-regions-outside-eu` controle la region de l'endpoint appele via `aws:RequestedRegion`. La decision confirmee est `eu-*`, y compris Londres et Zurich ; il ne s'agit pas des seuls pays de l'Union europeenne. La region du workload reste `eu-west-1`. Policy et attachement sandbox crees ensemble (2 ajouts). Le proprietaire confirme le refus EC2 hors Europe, les acces EC2 Europe/IAM/CloudFront preserves et le plan sans changement (code 0).

Le [JSON versionne](../terraform/modules/aws-scp/policies/deny-regions-outside-eu.json) constitue la liste exacte des exceptions. Avec `Deny` et `NotAction`, les actions listees echappent a cette regle de refus ; elles ne recoivent aucune permission supplementaire. Aucun role administrateur n'est exempte de la policy.

## Exceptions

| Actions | Justification et limite |
|---|---|
| `iam:*`, `organizations:*`, `account:*` | Identites et administration globale ; les restrictions propres aux comptes membres restent applicables |
| `sts:*` | Preserver les sessions et assume-role, y compris via les endpoints regionaux ; ce n'est pas une autorisation des actions effectuees ensuite |
| `route53:*`, `route53domains:*`, `cloudfront:*` | DNS, domaines et distributions globales ; aucune garantie de localisation europeenne de leur effet |
| `support:*`, `health:*` | Support et consultation de sante AWS |
| `budgets:*`, `ce:*`, `cur:*`, `pricing:*` | Budgets, couts et tarifs ; les permissions IAM et acces de facturation restent necessaires |
| `s3:ListAllMyBuckets`, `s3:GetBucketLocation` | Decouverte des buckets et de leur region, sans acces aux objets |
| `s3:GetAccountPublicAccessBlock`, `s3:PutAccountPublicAccessBlock` | Gestion de la protection publique au niveau compte ; son durcissement releve de la future SCP S3 |
| `s3:ListMultiRegionAccessPoints` | Consultation globale des points d'acces, sans autorisation d'en creer |

Aucun `s3:*`, `ec2:*`, `kms:*` ou `config:*` dans les exceptions. Les operations regionales de ces services restent soumises au refus. La liste est adaptee aux services du projet et doit etre revue lorsqu'un nouveau service global devient necessaire.

## Limites

La cle `aws:RequestedRegion` controle l'endpoint, pas tous les effets geographiques d'une requete. Cette policy ne constitue pas une garantie de residence des donnees ; les operations S3 interregions demandent des controles complementaires si cette garantie devient un objectif.

ACM et WAF pour CloudFront necessitent des operations en `us-east-1`. Ils ne sont pas exemptes dans cette premiere version : leurs appels hors Europe seront bloques. Avant extension aux OUs utiles et avant le workload edge du Sprint 3, concevoir et tester une exception ciblee pour ces dependances. Ne pas ajouter silencieusement `acm:*`, `wafv2:*` ou `kms:*` aux exceptions globales. Cette restriction temporaire est explicite et ne change pas la cible CloudFront/WAF du projet.

La policy ne doit pas encore etre propagee aux OUs Workloads ou Security. Attachement conserve uniquement sur le compte sandbox ; les quatre consultations de test sont validees, sans pretendre couvrir toutes les actions. Conserver `FullAWSAccess` et l'acces management pour le rollback. Aucun attachement restrictif au root Organizations.

## Sources

- [Exemple AWS de controle regional](https://github.com/aws-samples/service-control-policy-examples/blob/main/Region-controls/Deny-access-to-AWS-based-on-the-requested-AWS-region.json) : principe de refus avec exceptions, adapte au projet plutot que copie integralement.
- [Cle IAM aws:RequestedRegion](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html#condition-keys-requestedregion) : controle de l'endpoint et limites interregions.
- [Certificats CloudFront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html) et [endpoints WAF](https://docs.aws.amazon.com/general/latest/gr/waf.html) : dependances du futur edge.
