# Sprint 2 - Landing Zone AWS

[Objectif](#objectif) - [Tableau de bord](#tableau-de-bord) - [Cadrage initial](#cadrage-initial) - [Couts et destruction](#couts-et-destruction) - [Taches](#taches) - [Preuves](#preuves) - [Decisions et ecarts](#decisions-et-ecarts)

## Objectif

Poser une Landing Zone AWS multi-comptes depuis un compte existant promu en management account, avec un cout permanent minimal, et livrer en meme temps le state Terraform `bootstrap` dont tous les sprints suivants dependent.

Conception cible : [`docs/sprint-planning.md - Sprint 2`](../sprint-planning.md#sprint-2--landing-zone--terraform-modules-aws-organizations).

Ce sprint est le premier a engager des couts AWS reels et a manipuler des controles capables de verrouiller l'acces au compte. Les precautions ne sont donc pas de meme nature que celles des Sprints 0 et 1, ou le pire cas etait un cluster local a reconstruire.

## Tableau de bord

| ID | Tache | Etat | Depend de |
|---|---|---|---|
| S2-T1 | Poser la structure Terraform du depot et les conventions | Termine | S1 |
| S2-T2 | Creer le state `bootstrap` : backend S3, verrou, chiffrement | Termine | S2-T1 |
| S2-T3 | Module `aws-organization` : Organization, OUs, comptes enfants | Termine | S2-T2 |
| S2-T4 | Module `aws-scp` : six SCPs, testees en sandbox avant les OUs | En cours | S2-T3 |
| S2-T5 | Module `aws-sso` : IAM Identity Center et permission sets | En cours | S2-T3 |
| S2-T6 | Module `aws-baseline` : CloudTrail, Config, budgets, toggle de posture | Planifie | S2-T3 |
| S2-T7 | Role OIDC GitLab vers AWS, sans cle IAM longue duree | Planifie | S2-T2 |
| S2-T8 | Documenter account vending, services globaux, couts et destruction | Planifie | S2-T4, S2-T5, S2-T6, S2-T7 |

## Cadrage initial

Sprint cadre le 2026-09-09. Aucune ressource AWS creee a ce stade.

### Point de depart

Un compte AWS existant sert de point de depart. Au moment du cadrage, il n'appartenait a aucune Organization. Il est devenu le **management account** lors de S2-T3, sans destruction ni migration de ses ressources existantes.

Compte retenu le 2026-09-10, apres inventaire de trois comptes accessibles depuis le poste. Son identifiant n'est pas versionne, conformement aux regles du depot sur les identifiants de comptes reels : il vit dans un `terraform.tfvars` local et dans un profil AWS CLI dedie.

Etat verifie du compte au moment du choix :

| Point | Constat |
|---|---|
| Organization | Aucune, `AWSOrganizationsNotInUseException`. Le compte est eligible |
| Droits disponibles | Un utilisateur IAM avec `AdministratorAccess`, suffisant pour Organizations |
| Contenu preexistant | **Non vide** : un POC Bedrock AgentCore et un bootstrap CDK datant de juillet 2026, en `us-east-1` |
| Consommation | `0.00 USD` sur les 30 derniers jours. Le POC est dormant et le credit intact |
| MFA | **Absente** sur l'utilisateur administrateur, qui porte une cle d'acces statique active |
| Alias de compte | Aucun, l'URL de console reste l'identifiant numerique |

Deux consequences a retenir de cet inventaire.

Les ressources residuelles sont en `us-east-1`, hors du perimetre de la SCP `deny-regions-outside-eu`. Elles ne seront pourtant pas cassees, parce que **les SCPs ne s'appliquent jamais au management account**. C'est aussi la raison de fond pour laquelle ce compte ne doit porter aucun workload : c'est le seul de l'organisation sur lequel aucun garde-fou ne s'applique.

Le budget `cout-reel` livre en `S2-T6` verra la consommation de ce POC si elle reprend. L'attribution a ShopDemo devra donc reposer sur les tags obligatoires et non sur le total du compte.

Consequence structurante : le management account n'est jamais un compte de workload. Aucune ressource ShopDemo n'y sera deployee. Il porte l'Organization, les SCPs, IAM Identity Center, le CloudTrail organisationnel, et le state `bootstrap`.

### Prerequis avant S2-T2

| Action | Etat | Note |
|---|---|---|
| MFA sur l'utilisateur administrateur | `Fait` le 2026-09-10 | Cle U2F. La MFA du compte root etait deja active |
| Alias de compte `shopdemo-mgmt` | `Fait` le 2026-09-10 | L'URL de console devient lisible sans le numero de compte |
| Profil AWS CLI dedie | `Fait` le 2026-09-10 | Profil `shopdemo-mgmt` ajoute a cote de l'existant plutot qu'en remplacement, ce qui permet a chacun de porter sa propre region : `eu-west-1` pour ShopDemo, `us-east-1` conservee pour le POC preexistant |
| Statuer sur les residus du POC | `A faire`, sans urgence | Cout nul aujourd'hui. A trancher avant `S2-T6`, sans quoi une reprise du POC brouillerait l'attribution de cout |

Contrepartie assumee du profil ajoute plutot que renomme : la meme cle d'acces existe desormais en double dans `~/.aws/credentials`. Une rotation de cette cle devra mettre a jour les deux sections, sans quoi l'une des deux cessera de fonctionner sans explication evidente. Le point disparaitra quand la cle statique sera retiree au profit d'Identity Center en `S2-T5`.

Nuance importante sur la MFA. Elle protege la connexion console, pas la cle d'acces statique de l'utilisateur administrateur, active depuis juillet 2026. Une cle d'acces contourne la MFA par construction, sauf policy exigeant explicitement `aws:MultiFactorAuthPresent`. Cette cle est necessaire pour amorcer `S2-T2` ; sa desactivation est prevue une fois Identity Center livre en `S2-T5` et le role OIDC en `S2-T7`.

Contenu exact des residus, pour que la decision se prenne sur des faits : une stack CDK `CDKToolkit`, et une stack `AgentCore` portant un `Runtime`, une `Gateway` MCP avec sa cible, une Lambda avec son log group et quatre roles IAM. Detruire `CDKToolkit` obligerait a refaire un `cdk bootstrap` avant tout futur deploiement CDK sur ce compte et cette region.

Point non verifie : l'exposition et le mode d'authentification de la `Gateway` AgentCore n'ont pas ete controles, le CLI installe ne connaissant pas l'API `bedrock-agentcore-control`.

### Comptes cibles

Quatre comptes enfants, repartis en trois OUs :

| OU | Compte | Role | Ressources attendues |
|---|---|---|---|
| `Security` | `security-audit` | Journalisation et posture | CloudTrail, Config, buckets de logs |
| `Workloads` | `workload-staging` | Environnement ephemere | VPC, EKS, RDS a partir du Sprint 3 |
| `Workloads` | `workload-prod` | Environnement ephemere | VPC, EKS, RDS a partir du Sprint 3 |
| `Sandbox` | `sandbox` | Banc d'essai destructif | Aucune, volontairement |

Le compte `sandbox` est conserve alors qu'il ne portera rien. Il ne coute rien par lui meme et il est le seul endroit ou une SCP de type `deny-root-usage` ou `require-mfa-for-console` peut etre eprouvee sans risquer de bloquer un compte utile. Sans lui, le test se ferait sur `workload-staging`, c'est a dire sur le compte qui portera EKS au Sprint 3.

Chaque compte demande une adresse email unique. Ces adresses ne sont jamais versionnees : elles sont passees en variables Terraform non commitees, conformement aux regles du depot sur les informations personnelles.

### Sequencement impose

Le Sprint 2 contient une dependance circulaire apparente qu'il faut resoudre explicitement, sinon le sprint se bloque des la premiere commande.

Le backend S3 qui heberge les states ne peut pas etre decrit dans un state qui vit deja dans ce backend. Le role OIDC GitLab, qui doit permettre a la CI de s'authentifier sans cle, n'existe pas non plus au demarrage. Les premiers `apply` se font donc necessairement depuis le poste local, avec des credentials du compte management, sur un state local.

Ordre retenu :

```text
1. state local  -> creation du bucket S3, du chiffrement et du verrou   (S2-T2)
2. migration    -> le state bootstrap est deplace vers ce bucket        (S2-T2)
3. state S3     -> Organization, OUs, comptes                           (S2-T3)
4. state S3     -> SCPs, Identity Center, baseline, role OIDC           (S2-T4 a S2-T7)
5. bascule CI   -> a partir du Sprint 3, la CI s'authentifie par OIDC
```

<p align="center"><img src="../diagrams/s2-bootstrap-state-sequence.svg" alt="Amorcage du state bootstrap" width="720"></p>

> Rendu interactif : [`../diagrams/s2-bootstrap-state-sequence.html`](../diagrams/s2-bootstrap-state-sequence.html).

Le state local intermediaire est un artefact de bootstrap, pas une cible. Il est supprime apres migration et ne doit jamais etre commite.

### Rejouabilite du bootstrap

Terraform n'est pas idempotent au sens Ansible, il est convergent : il compare l'etat reel a l'etat desire et n'applique que l'ecart. Rejouer un `apply` sur du code inchange ne produit donc aucun changement, et cela se prouve avec `terraform plan -detailed-exitcode`, qui retourne `0` sans diff et `2` avec diff. C'est l'equivalent exact du `changed=0` utilise pour valider les roles Ansible au Sprint 0.

Le risque du state `bootstrap` n'est pas la rejouabilite, c'est le **remplacement**. Certains attributs ne sont pas modifiables en place : les changer fait que Terraform detruit puis recree la ressource. Deux cas sont graves ici.

| Ressource | Ce qui declenche un remplacement | Consequence |
|---|---|---|
| Bucket S3 du state | Renommage du bucket, son nom etant immuable | Terraform detruit le bucket qui contient le state en cours d'utilisation |
| Compte AWS enfant | Changement d'email, ou retrait de la declaration du code | Un compte AWS ne se supprime pas comme une ressource ordinaire, l'operation echoue ou laisse un compte orphelin |

Parade retenue : `lifecycle { prevent_destroy = true }` sur le bucket de state et sur les comptes enfants. Terraform refuse alors le plan au lieu de l'executer. La relecture de plan cherche systematiquement les marqueurs `-/+` et `# forces replacement`, pas seulement le nombre de ressources creees.

### Frontiere avec le Sprint 3

L'EC2 runner `bootstrap` decrit par [`ADR-003`](../adr/ADR-003-separate-bootstrap-and-workload-states.md) n'est **pas** cree dans ce sprint. Il appartient au state `bootstrap` et son code peut y etre prepare, mais il ne sert qu'aux jobs necessitant le reseau prive du VPC, lequel n'existe pas avant le Sprint 3. Le creer maintenant reviendrait a payer une instance permanente pour rien.

Le state `workload` n'est pas non plus ouvert dans ce sprint. Il arrive avec le VPC et EKS.

## Couts et destruction

### Couts attendus

Posture retenue : minimum permanent, avec la posture forte derriere un interrupteur.

| Poste | Compte | Cout mensuel estime | Statut |
|---|---|---|---|
| AWS Organizations | management | 0$ | Toujours actif |
| IAM Identity Center | management | 0$ | Toujours actif |
| SCPs | management | 0$ | Toujours actif |
| CloudTrail organisationnel, management events | security-audit | 0$ pour le premier trail | Toujours actif |
| Stockage S3 des logs CloudTrail | security-audit | environ 1$ | Toujours actif |
| AWS Config, deux regles seulement | security-audit | environ 2 a 3$ | Toujours actif |
| Bucket S3 du state Terraform | management | negligeable | Toujours actif |
| Budgets, deux, et Cost Anomaly Detection | management | 0$ sous reserve du quota gratuit | Toujours actif |
| GuardDuty sur quatre comptes | tous | environ 4$ par jour actif | `enable_full_posture = false` |
| Regles AWS Config CIS completes | tous | variable, significatif | `enable_full_posture = false` |

Cible : environ 5$ par mois en permanence. La posture forte s'active en debut de session avec `enable_full_posture = true` et se desactive en fin de session.

### Credits AWS et lisibilite du cout

Le compte de depart etant recent, il dispose probablement de credits. Ils creent un angle mort qu'il faut fermer des `S2-T6`.

Un AWS Budget de type cout mesure par defaut le cout **apres application des credits**. Tant que les credits couvrent la facture, il affiche zero et n'apprend rien.

Deux budgets sont donc livres plutot qu'un, parce qu'ils repondent a deux questions differentes :

| Budget | Reglage | Question a laquelle il repond | Seuil |
|---|---|---|---|
| `cout-reel` | `include_credit = false`, `include_refund = false` | Combien mon architecture consomme-t-elle reellement ? | Cale sur la cible de train de depense du sprint |
| `cout-facture` | Credits inclus, comportement par defaut | Combien vais-je reellement payer ? | Bas et proche de zero |

Le second est en pratique un **detecteur d'epuisement des credits**. Il reste a zero tant qu'ils couvrent la facture ; le jour ou il sort de zero, la situation a change et il faut le savoir sans attendre le releve mensuel. Le premier reste le signal FinOps du projet et ne depend pas des credits.

Cette paire ne dit rien sur la repartition par compte. L'attribution est portee par les tags obligatoires poses en `S2-T1` et lue dans Cost Explorer, plutot que par un budget par compte. Les budgets par compte sont reportes au Sprint 3, quand les comptes de workload commenceront reellement a depenser.

Deux points a verifier en `S2-T6`, non confirmes a ce stade :

- AWS Budgets offre un quota gratuit de budgets par compte, au dela duquel chaque budget supplementaire est factures a la journee. Deux budgets restent probablement dans le gratuit, ce qui est une raison de plus de ne pas multiplier les budgets par compte des maintenant. A confirmer avant d'en ajouter ;
- avec la facturation consolidee d'une Organization, le Free Tier et les credits sont mutualises au niveau du compte payeur. Si c'est le cas, creer quatre comptes enfants ne donne pas quatre fois le Free Tier, et aucun dimensionnement ne doit reposer sur l'hypothese inverse.

Ces montants sont des **estimations non verifiees** a ce stade. Ils devront etre confrontes a la facturation reelle apres le premier mois complet, et corriges ici.

### Procedure de destruction

Contrairement au state `workload`, la Landing Zone n'est pas concue pour etre detruite apres chaque session. Ce qui doit etre reversible est autre chose : la posture couteuse et les erreurs de cadrage.

| Element | Reversibilite | Procedure |
|---|---|---|
| Posture forte | Immediate | `enable_full_posture = false` puis apply |
| SCP appliquee a une OU | Immediate | Detacher la policy, l'effet cesse en quelques secondes |
| Compte enfant | Lente et partielle | Un compte AWS ne se supprime pas par Terraform : il se ferme depuis la console, avec 90 jours de periode suspendue |
| Organization | Bloquee tant que des comptes enfants existent | Retirer ou fermer les comptes d'abord |
| Bucket de state | Manuelle et deliberee | Jamais detruit par pipeline, versioning active |

Le point a retenir avant le premier apply : **la creation d'un compte AWS est difficilement reversible**. Une erreur d'email ou de nom se corrige mal. Cette etape merite une relecture du plan plus attentive que le reste du sprint.

### Risques identifies

| Risque | Impact | Mitigation retenue |
|---|---|---|
| Verrouillage par SCP | Perte d'acces a un compte | Test systematique en `sandbox`, jamais d'attachement direct a la racine |
| SCP regionale cassant un service global | Pannes IAM, Route 53, CloudFront | Exclusion explicite documentee dans `docs/scp-global-services.md` |
| Cle IAM longue duree introduite pour debloquer la CI | Faille de securite durable | Role OIDC livre dans le meme sprint, aucune cle statique acceptee |
| Derive de cout non vue | Facture surprise | Budgets et Cost Anomaly Detection livres en `S2-T6`, avant les ressources couteuses du Sprint 3 |
| State local oublie ou commite | Fuite d'etat d'infrastructure | Migration vers S3 des `S2-T2`, entree `.gitignore` posee en `S2-T1` |

## Taches

### S2-T1 - Poser la structure Terraform du depot et les conventions

Etat : `Termine` le 2026-09-09.

Objectif : rendre le code Terraform lisible et validable avant qu'une seule ressource n'existe, sur le meme principe que `S1-T1` qui avait pose la structure GitOps sans rien appliquer.

Livrables :

- arborescence [`../../terraform/`](../../terraform/) a la racine, coherente avec `ansible/` et `gitops/` ;
- `terraform/bootstrap/` comme state racine, `terraform/modules/` pour les modules internes, `terraform/envs/` vide jusqu'au Sprint 3 avec un README expliquant pourquoi ;
- conventions documentees dans [`../../terraform/README.md`](../../terraform/README.md) : region, nommage, tags obligatoires, epinglage, secrets ;
- cinq tags obligatoires appliques par `default_tags` sur le provider plutot que repetes ressource par ressource, avec les memes cles que la future regle AWS Config `required-tags` de `S2-T6` ;
- validations sur les variables : `aws_region` refuse toute region hors d'Europe, `project` impose un format compatible avec le nommage des buckets S3, `environment` est contraint a une liste fermee ;
- configuration `tflint` versionnee dans `terraform/.tflint.hcl`, ruleset AWS `0.46.0` epingle ;
- section Terraform ajoutee au `.gitignore`, avec une exception explicite pour `.terraform.lock.hcl` ;
- `terraform/bootstrap/terraform.tfvars.example` sans aucune valeur reelle.

Deux points meritent d'etre releves.

Le backend n'est volontairement pas declare. Un commentaire dans `versions.tf` explique pourquoi et annonce ce que `S2-T2` y ajoutera, plutot que de laisser un lecteur croire a un oubli.

Le fichier `.terraform.lock.hcl` est **committe volontairement**, contre l'intuition qui pousse a ignorer tout ce qui commence par `.terraform`. Il fige les empreintes des providers et garantit que la CI installera exactement les memes binaires que le poste local. C'est le seul fichier `.terraform*` qui entre dans Git, d'ou la ligne de negation dans le `.gitignore`.

Resultats de validation :

| Commande | Resultat |
|---|---|
| `terraform -chdir=terraform/bootstrap init -backend=false` | AWS provider `v6.63.0` installe, lock file genere |
| `terraform fmt -recursive -check terraform/` | Aucun fichier a reformater |
| `terraform -chdir=terraform/bootstrap validate` | `Success! The configuration is valid.` |
| `tflint --chdir=terraform/bootstrap --config=.../terraform/.tflint.hcl` | Sortie vide, code de retour `0` |
| `git check-ignore` sur state, tfvars et `.terraform/` | Ignores. `.terraform.lock.hcl` et le fichier d'exemple restent suivis |

Aucune ressource AWS creee, aucun appel a AWS. `init -backend=false` ne fait que telecharger les providers et n'ecrit aucun state.

### S2-T2 - Creer le state bootstrap

Etat : `Termine` le 2026-09-10.

Objectif : sortir du state local le plus tot possible, avec un backend chiffre, versionne et verrouille.

Livrables realises, dans [`../../terraform/bootstrap/s3-state.tf`](../../terraform/bootstrap/s3-state.tf) :

- bucket S3 dedie, nomme `<project>-<environment>-tfstate-<compte>` ;
- versioning actif, avec expiration des versions anciennes a 30 jours pour borner la croissance ;
- chiffrement au repos `AES256`, et nettoyage des uploads multipart incomplets a 7 jours ;
- blocage complet de l'acces public, quatre verrous poses ;
- `object_ownership = BucketOwnerEnforced`, ce qui desactive les ACL et laisse la policy seule autorite ;
- `lifecycle { prevent_destroy = true }` sur le bucket ;
- verrou S3 natif via `use_lockfile = true`, **aucune table DynamoDB** ;
- migration effective du state local vers S3, puis suppression du state local.

### Deux garde-fous poses pendant la tache

`allowed_account_ids` sur le provider fait echouer Terraform si les credentials resolus ne pointent pas sur le compte attendu. Sans cela, un profil oublie enverrait un apply dans un compte voisin, et la creation d'une Organization en `S2-T3` se defait mal.

Le bloc `backend` est en **configuration partielle**. Le nom du bucket contient l'identifiant du compte, qui ne doit pas etre versionne : `key`, `encrypt` et `use_lockfile` vivent dans le code, tandis que `bucket`, `region` et `profile` vivent dans un `backend.hcl` ignore par git, passe via `-backend-config`. Un [`backend.hcl.example`](../../terraform/bootstrap/backend.hcl.example) documente la forme attendue.

### Ce que la migration a appris

La premiere tentative de migration a echoue sur un `403 Forbidden` en lisant l'objet de state, alors que l'utilisateur porte `AdministratorAccess`.

Cause racine : **le backend ne lit pas le bloc `provider`**. Il resout ses credentials independamment, par la chaine par defaut. Celle-ci pointait ici vers un compte sans rapport, verifie par un `aws sts get-caller-identity` sans profil. Le garde-fou `allowed_account_ids` ne protege donc que le provider, jamais le backend, et un backend mal credite echoue au moment le plus sensible de la sequence, celui ou le state quitte le poste.

Correctif : `profile` ajoute a `backend.hcl`. La lecon vaut au dela de ce projet : provider et backend sont deux clients AWS distincts, configures separement.

Criteres d'acceptation, tous verifies :

| Critere | Resultat |
|---|---|
| Bucket conforme | `eu-west-1`, versioning `Enabled`, `AES256`, quatre verrous publics a `True`, `BucketOwnerEnforced`, retention 30 jours, cinq tags obligatoires presents |
| State migre | `bootstrap/terraform.tfstate`, 12 077 octets dans S3, chiffre `AES256` |
| State local supprime | Plus aucun `*.tfstate` dans le repertoire de travail |
| Verrouillage effectif | Deux executions concurrentes : la premiere reussit, la seconde echoue avec `Error acquiring the state lock` |
| Rejouabilite | `terraform plan -detailed-exitcode` rejoue retourne `0` |
| Aucun identifiant versionne | `terraform.tfvars` et `backend.hcl` ignores, verifies par `git check-ignore` |

Cout constate : le state pese 12 Ko. La facturation S3 Standard a 0,023 USD par Go et par mois rend ce poste negligeable, conformement a l'estimation du cadrage.

### S2-T3 - Module aws-organization

Etat : `Termine` le 2026-09-24.

Module et appel bootstrap prepares : [guide et interface](../../terraform/modules/aws-organization/README.md). OUs et comptes utilisent des cles stables, les emails sensibles sont controles pour format, ensemble des cles et unicite. Organization, OUs et comptes portent `prevent_destroy`.

Validations locales du 2026-09-24 : `terraform validate` sur bootstrap et TFLint passent ; `terraform test` avec provider AWS simule 6.63.0 passe (3 tests : topologie, emails dupliques, compte manquant). Aucun test ne cree de ressource AWS. `terraform fmt -recursive -check terraform/` et `git diff --check` passent.

Plan AWS reel produit et relu le 2026-09-24, apres renseignement des emails locaux : `terraform plan -input=false -lock-timeout=30s -detailed-exitcode -out=tfplan` retourne 2 (changements prevus). Inspection JSON : huit creations (une Organization ALL, trois OUs, quatre comptes), aucune modification, suppression ou remplacement ; six ressources S3 et sorties existantes inchangees, aucune derive detectee. Correspondance des quatre emails avec les cles d'entree verifiee sans journaliser les valeurs. Plan et tfvars ignores par Git. Validation finale realisee par le proprietaire et rapportee dans la session : reception des emails test confirmee ; `terraform apply tfplan` termine avec `8 added, 0 changed, 0 destroyed` ; `terraform plan -detailed-exitcode` retourne `No changes` et le code `0` ; rattachements des quatre comptes aux trois OUs confirmes dans la console AWS Organizations. Ces controles AWS n'ont pas ete reexecutes par l'agent.

Objectif : creer l'Organization depuis le compte existant, les trois OUs et les quatre comptes enfants.

Livrables :

- module `terraform/modules/aws-organization/` ;
- Organization avec `all_features` active, condition necessaire aux SCPs et a Identity Center ;
- OUs `Security`, `Workloads`, `Sandbox` ;
- quatre comptes enfants, emails passes en variables non versionnees ;
- `lifecycle { prevent_destroy = true }` sur les comptes enfants.

Criteres d'acceptation : plan relu ligne a ligne avant apply, en verifiant nommement chaque email et chaque nom de compte, et en cherchant explicitement les marqueurs `-/+` et `# forces replacement`. Les quatre comptes apparaissent dans l'Organization et sont rattaches a la bonne OU. Un `plan -detailed-exitcode` rejoue apres apply retourne `0`.

### S2-T4 - Module aws-scp

Etat : `En cours`.

Preuves rapportees par le proprietaire le 2026-09-25 : acces console IAM active pour l'utilisateur administrateur existant ; bascule vers `OrganizationAccountAccessRole` dans sandbox reussie ; activation manuelle du type SCP ; consultation EC2 initialement possible en `eu-west-1` et `us-east-1`, puis refusee uniquement hors Europe apres attachement au compte sandbox de `test-deny-ec2-outside-europe`. Acces retabli apres detachement et policy temporaire supprimee. `FullAWSAccess` conserve. Ce test pedagogique limite a EC2 ne valide pas encore la policy regionale complete.

L'activation est maintenant declaree par `enabled_policy_types = ["SERVICE_CONTROL_POLICY"]` dans le module Organization. Le proprietaire confirme le plan de convergence sans changement (code 0). Aucun apply lance par l'agent.

Premiere policy deployee dans [aws-scp](../../terraform/modules/aws-scp/README.md) : `deny-regions-outside-eu`, scope `eu-*` confirme, exceptions detaillees dans [scp-global-services.md](../scp-global-services.md). La premiere reponse « c ok » avait ete interpretee a tort comme une confirmation d'apply : le `terraform state list` transmis ensuite ne contenait pas la policy. Le proprietaire a finalement cree ensemble la policy et son attachement au seul compte sandbox avec `2 added, 0 changed, 0 destroyed`.

Validations AWS rapportees par le proprietaire le 2026-09-25 : avant attachement, les quatre consultations etaient accessibles ; apres attachement, EC2 Instances en `us-east-1` est refuse, EC2 Instances en `eu-west-1`, IAM Roles et CloudFront Distributions restent accessibles. Le plan apres apply retourne `No changes` et le code `0`. L'attachement Terraform est conserve. Ces preuves couvrent les quatre consultations, pas toutes les actions ni toutes les exceptions de la policy.

Les cinq autres SCPs et leurs attachements sandbox ont ete deployes en un lot a la demande du proprietaire. Le provider `aws.sandbox` configure d'abord les quatre protections S3 de compte, avant l'attachement de `deny-public-s3`. Le plan annoncait onze ajouts, aucune modification ou suppression ; le proprietaire confirme son apply. Les limites MFA (utilisateurs IAM directs, pas roles), root et CloudTrail ainsi que les preuves manquantes sont explicites dans le [guide SCP](../../terraform/modules/aws-scp/README.md#lot-sandbox-complet). Validation AWS rapportee pour S3 : via un profil local nomme assumant `OrganizationAccountAccessRole`, une reecriture des quatre protections a `true` avec `s3:PutAccountPublicAccessBlock` est refusee explicitement par une SCP ; aucune protection n'a ete diminuee. Les autres effets du lot ne sont pas encore revendiques comme verifies. Validation locale du lot : bootstrap `terraform validate`, TFLint, six tests Terraform simules et trente-quatre cas de requetes Python reussis ; formatage et controle du diff OK. Les exceptions ACM/WAF de CloudFront restent a concevoir avant extension aux OUs utiles. Validations locales precedentes : `terraform validate` sur module et bootstrap, TFLint du bootstrap, un test Terraform avec provider simule et matrice Python de quatorze requetes reussis. Aucun appel AWS reexecute par l'agent pour enregistrer les confirmations du proprietaire.

Avant le test MFA reel, un defaut de conception a ete corrige : la premiere version refusait aussi les actions necessaires a l'enrolement du dispositif. La policy suit maintenant le modele AWS `Deny` avec `NotAction`, limite aux appels d'enrolement et a `sts:GetSessionToken`, tout en refusant notamment la suppression d'un dispositif sans MFA. Les tests locaux passent ; le proprietaire a confirme le plan puis l'apply de cette modification en place. Le resume exact de l'apply n'a pas ete conserve comme preuve.

Objectif : livrer les six SCPs prevues, en prouvant leur effet avant de les appliquer aux comptes utiles.

Livrables :

- module `terraform/modules/aws-scp/` avec `deny-root-usage`, `deny-regions-outside-eu`, `require-mfa-for-console`, `deny-public-s3`, `enforce-cloudtrail`, `deny-iam-longterm-keys` ;
- exclusion explicite des services globaux dans `deny-regions-outside-eu` ;
- pour chaque SCP, une preuve d'effet obtenue en `sandbox` : une action qui reussit avant attachement et echoue apres.

Une SCP qui n'a jamais rien bloque dans un test n'est pas une preuve. La validation attendue est une mesure avant et apres, sur le modele de ce qui a ete fait pour les NetworkPolicies en `S1-T3`.

Criteres d'acceptation : chaque SCP est attachee a une OU seulement apres avoir ete eprouvee en `sandbox`, et aucune n'est attachee a la racine de l'Organization.

### S2-T5 - Module aws-sso

Etat : `En cours`.

Le module, sa matrice d'acces et ses tests locaux sont disponibles dans [terraform/modules/aws-sso](../../terraform/modules/aws-sso/README.md). L'instance d'organisation IAM Identity Center est active dans `eu-west-1`, le module est deploye et l'utilisateur voit la matrice attendue dans le portail.

Premiere tentative d'apply S2-T5 : echec sans creation Identity Center. L'activation console avait ajoute l'acces de confiance Organizations `sso.amazonaws.com`, mais `aws_organizations_organization.this` ne le declarait pas. Terraform l'a retire au debut de l'apply, puis les trois groupes ont echoue avec `IdentityStore not present` et les trois permission sets avec `IAM Identity Center instance is inaccessible`. Cause corrigee dans le module Organization : l'acces de confiance fait maintenant partie de l'etat desire. La reprise doit montrer une modification de l'Organization pour le retablir et dix-neuf creations Identity Center, sans autre changement.

Reprise reussie apres restauration et declaration de l'acces de confiance : le proprietaire confirme `Apply complete! Resources: 19 added, 0 changed, 0 destroyed.` Les trois groupes, trois permission sets, trois attachements de policies et dix affectations de comptes sont maintenant deployes. L'utilisateur est cree, active et rattache aux groupes `ShopDemo-Developers` et `ShopDemo-Readers` ; le test fonctionnel des droits reste a effectuer.

Validation portail rapportee par le proprietaire : l'utilisateur Identity Center est active et voit les quatre comptes membres. `DevAccess` et `ReadOnly` apparaissent sur sandbox et workload-staging ; seul `ReadOnly` apparait sur workload-prod et security-audit ; `AdminAccess` n'apparait nulle part. La capture transmise n'est pas versionnee car elle contient les identifiants et emails reels des comptes. Il reste a confirmer une action autorisee avec `DevAccess` et la meme action refusee avec `ReadOnly`.

Frontiere d'automatisation retenue : l'instance d'organisation est activee manuellement une seule fois, car l'API AWS `CreateInstance` ne permet pas de la creer depuis le management account. Terraform decouvre ensuite cette instance et gere les groupes, permission sets, policies et affectations. L'utilisateur du proprietaire reste manuel dans ce lab pour ne pas inscrire son identite personnelle dans le state ; en entreprise, cette partie serait normalement synchronisee depuis un fournisseur d'identite via SCIM. Aucun groupe, permission set ou rattachement de compte ne doit etre cree manuellement apres le bootstrap.

<p align="center"><img src="../diagrams/s2-identity-center-access.svg" alt="Acces IAM Identity Center aux comptes membres et chemin break-glass" width="1100"></p>

Le chemin courant passe par le portail, un groupe et un permission set. Le chemin d'urgence IAM reste separe et limite au management account tant qu'Identity Center et OIDC ne sont pas totalement valides.

Objectif : remplacer l'usage d'utilisateurs IAM par un acces federe, avec des permission sets differencies.

Livrables :

- module `terraform/modules/aws-sso/` ;
- permission sets `AdminAccess` reserve au break-glass, `DevAccess`, `ReadOnly` ;
- affectations par compte et par OU ;
- procedure de break-glass documentee, y compris ce qui se passe si Identity Center devient inaccessible.

Criteres d'acceptation : une connexion reelle via le portail Identity Center aboutit sur au moins deux permission sets differents, avec des droits effectivement differents.

### S2-T6 - Module aws-baseline

Etat : `Planifie`.

Objectif : poser la journalisation, la detection de derive de cout et la posture de securite, avec un interrupteur qui separe le permanent du couteux.

Livrables :

- module `terraform/modules/aws-baseline/` avec la variable `enable_full_posture` ;
- toujours actif : CloudTrail organisationnel multi-region, AWS Config limite a `required-tags` et `cloudtrail-enabled`, bucket S3 de logs, **deux budgets** `cout-reel` hors credits et `cout-facture` credits inclus, Cost Anomaly Detection ;
- derriere l'interrupteur : GuardDuty sur les quatre comptes et les regles AWS Config CIS completes ;
- procedure d'activation et de desactivation en debut et fin de session.

Criteres d'acceptation : un evenement realise dans un compte enfant apparait dans le CloudTrail centralise, et l'interrupteur produit bien un plan qui cree ou detruit uniquement les ressources couteuses.

### S2-T7 - Role OIDC GitLab vers AWS

Etat : `Planifie`.

Objectif : permettre a la CI GitLab d'obtenir des credentials AWS temporaires sans qu'aucune cle longue duree n'existe.

Livrables :

- provider OIDC GitLab declare dans le compte management ;
- role assumable, avec une condition de trust restreignant le projet GitLab et la reference Git autorisee ;
- permissions limitees a ce dont le Sprint 3 aura besoin, pas davantage ;
- validation par un job GitLab reel qui obtient une identite AWS.

La condition de trust est le point sensible. Une condition trop large laisse n'importe quel projet GitLab.com assumer le role. La restriction doit porter au minimum sur le chemin du projet.

Criteres d'acceptation : un job de la CI execute `aws sts get-caller-identity` avec succes, et un job depuis une reference non autorisee echoue.

### S2-T8 - Documentation du sprint

Etat : `Planifie`.

Objectif : rendre la Landing Zone exploitable et reproductible par quelqu'un qui n'a pas vecu le sprint.

Livrables :

- `docs/account-vending.md`, procedure de creation d'un compte supplementaire ;
- `docs/scp-global-services.md`, services globaux exclus de `deny-regions-outside-eu` et pourquoi ;
- couts reels constates, en remplacement des estimations de ce fichier ;
- procedure de destruction et limites de reversibilite verifiees plutot que supposees.

## Preuves

| Controle | Etat | Preuve |
|---|---|---|
| Structure Terraform | Verifie | `terraform fmt -recursive -check`, `validate` et `tflint` passent, aucune ressource creee |
| Coherence documentaire | Verifie | Arborescences, schemas AWS et chapitres pedagogiques alignes sur l'etat reel le 2026-09-09 |
| Schemas regenerables | Verifie | `render-architecture.mjs` puis `export-svg.py`, methode validee en reproduisant a l'octet pres un SVG deja commite |
| State et secrets hors de Git | Verifie | `git check-ignore` : state, `*.tfvars` et `.terraform/` ignores, `.terraform.lock.hcl` suivi |
| Backend S3 operationnel | Verifie | State migre dans S3, chiffre `AES256`, `plan` rejoue sans ecart |
| Verrouillage de state | Verifie | Deux executions concurrentes, la seconde rejetee avec `Error acquiring the state lock` |
| Backend et provider distincts | Verifie | Migration en echec `403` tant que `backend.hcl` ne portait pas son propre `profile` |
| Organization et comptes | Verifie | Plan relu ; apply 8 ajouts, plan suivant code 0 et rattachements confirmes par le proprietaire le 2026-09-24 |
| Effet des SCPs | Partiellement verifie | Region et verrouillage S3 confirmes en sandbox ; root, MFA, cles IAM et CloudTrail restent a tester ou a marquer explicitement non verifies |
| Services globaux preserves | A produire | Appel a un service global reussi malgre `deny-regions-outside-eu` |
| Acces federe | A produire | Connexion reelle sur deux permission sets aux droits distincts |
| Journalisation centralisee | A produire | Evenement d'un compte enfant retrouve dans le CloudTrail central |
| Rejouabilite du bootstrap | A produire | `terraform plan -detailed-exitcode` rejoue retourne `0` |
| Protection contre le remplacement | A produire | Plan refuse par `prevent_destroy` sur le bucket de state et sur un compte enfant |
| Budgets lisibles malgre les credits | A produire | `cout-reel` affiche un montant non nul alors que `cout-facture` reste a zero, sur la meme periode |
| Interrupteur de posture | A produire | Plan d'activation et de desactivation limite aux ressources couteuses |
| Authentification CI sans cle | A produire | `aws sts get-caller-identity` reussi en job GitLab, echec depuis une reference non autorisee |
| Couts reels | A produire | Facturation du premier mois complet |

## Decisions et ecarts

- Decision : le compte AWS existant est promu management account. Aucune ressource ShopDemo n'y sera jamais deployee.
- Decision : quatre comptes enfants, dont `sandbox` qui ne portera aucune ressource. Il est conserve parce qu'il est le seul lieu ou une SCP peut etre eprouvee sans consequence.
- Decision : le state `bootstrap` entre dans ce sprint plutot que dans le Sprint 3, pour eviter une migration de state ulterieure et pour que l'OIDC existe avant le premier besoin de la CI.
- Decision : l'EC2 runner `bootstrap` n'est pas cree dans ce sprint. Il n'a d'utilite qu'avec un VPC, qui arrive au Sprint 3, et il couterait une instance permanente entre temps.
- Ecart avec [`docs/sprint-planning.md`](../sprint-planning.md) : le planning annonce un « Override MiniStack pour validation locale avant apply reel ». Cette validation n'est pas realisable. [`docs/decouverte-ministack.md`](../decouverte-ministack.md) indique que `Organizations` et les `SCPs` sont hors perimetre de MiniStack et exigent AWS reel. Le garde-fou du Sprint 2 est donc la relecture de plan et le test en compte `sandbox`, pas l'emulation locale. Le planning doit etre corrige sur ce point.
- Ecart resolu en `S2-T1` : le planning supposait un repertoire `platform/` a la racine, visible dans `platform/terraform/envs/staging` mais aussi dans `platform/docs/oidc-maintenance.md` et `platform/docs/eks-upgrade.md`. Le depot pose `terraform/` a la racine, par coherence avec `ansible/` et `gitops/`, et les cinq occurrences de `docs/sprint-planning.md` ont ete alignees. Le repertoire `platform/` n'aurait porte qu'un seul enfant.
- Decision : `prevent_destroy` sur le bucket de state et sur les comptes enfants. Le risque du bootstrap n'est pas la rejouabilite, qui est acquise par la nature convergente de Terraform, mais le remplacement declenche par un attribut immuable.
- Decision : deux budgets plutot qu'un. `cout-reel` exclut credits et remises et porte le signal FinOps du projet ; `cout-facture` les inclut et sert de detecteur d'epuisement des credits. Un seul des deux ne repond qu'a la moitie de la question.
- Decision : pas de budget par compte dans ce sprint. L'attribution passe par les tags obligatoires et Cost Explorer ; les budgets par compte arrivent au Sprint 3, quand les comptes de workload depenseront.
- Passe de coherence documentaire du 2026-09-09, declenchee par `S2-T1`. Deux schemas publies etaient devenus faux : `organisation-aws` montrait `Control Tower` alors que le planning le place hors scope et n'avait aucun compte dans l'OU `Sandbox` ; `terraform-states` annoncait un verrou DynamoDB abandonne. Les deux arborescences du depot, dans `README.md` et `docs/architecture/07-repo-learning-path.md`, ignoraient `terraform/`. La dette pedagogique du Sprint 1 a ete soldee au passage : `docs/comment-ca-marche.md` s'arretait a `S1-T2` et couvre desormais `S1-T3` a `S1-T7` puis `S2-T1`.
- Decision : les schemas Archify se regenerent en ligne de commande via [`../diagrams/export-svg.py`](../diagrams/export-svg.py), qui reproduit hors navigateur le menu d'export du HTML. La methode a ete validee en regenerant un schema inchange et en comparant a l'octet pres au SVG deja commite, ce qui rend les schemas verifiables comme du code.
- Tranche en `S2-T1` : la version installee est Terraform `1.15.5`, largement au dessus de la `1.10` qui introduit le verrou S3 natif. `S2-T2` utilisera donc `use_lockfile = true` et **aucune table DynamoDB**. Le point ouvert du cadrage est ferme.
- Tranche en `S2-T1` : region `eu-west-1`, deja implicite dans le depot et desormais explicite, avec une validation de variable qui refuse toute region hors d'Europe par coherence avec la SCP `deny-regions-outside-eu`.
- Ecart resolu en `S2-T1` : `docs/sprint-planning.md` supposait une organisation multi-depots, un groupe GitLab `shopdemo` contenant `shopdemo-gitops` et `shopdemo-platform`. La realite actee par [`ADR-007`](../adr/ADR-007-gitlab-source-of-truth-github-mirror.md) et implementee au Sprint 1 est un mono-depot, `gitlab.com/ClementV78/shopdemo`, ou `gitops/` est un repertoire. Les six manifests Argo CD de `gitops/argocd/` le confirment. Les URL du planning ont ete corrigees.
- Consequence directe sur `S2-T7` : la condition de confiance OIDC du planning valait `project_path:monorg/idp-platform`, un placeholder. Elle doit valoir `project_path:ClementV78/shopdemo`. Une condition laissee trop large permettrait a n'importe quel projet GitLab.com d'assumer le role AWS.
- Consequence a retenir pour le Sprint 6 : en mono-depot, le commit GitOps produit par la CI atterrit dans le depot qui declenche cette meme CI. Le `[skip ci]` deja prevu au planning n'est donc pas une precaution mais une necessite, sans quoi la pipeline boucle sur elle meme.
