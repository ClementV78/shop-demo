# ADR-002 - Retirer Gitea de la cible MVP GitOps

## Statut

Accepte

## Contexte

La cible initiale prevoyait `Gitea` comme composant self-hosted pour heberger un
repository GitOps interne. L'idee etait de montrer une plateforme plus autonome :

- un serveur Git interne ;
- une organisation et des repositories crees par Ansible ;
- un token bot dedie pour mettre a jour le repo GitOps ;
- Argo CD lisant ce repo pour synchroniser Kubernetes.

Cette intention etait coherente avec une vision "plateforme interne complete",
mais elle ajoute une brique qui n'est pas necessaire au MVP actuel.

Le besoin GitOps minimal est plus simple :

```text
repository Git accessible -> Argo CD -> Kubernetes
```

Argo CD n'impose pas Gitea. Il peut lire un repository Git heberge sur
GitLab.com, GitHub, Gitea ou tout autre serveur Git accessible.

Le projet cherche maintenant a etre plus lisible, plus simple a expliquer et
plus centre sur sa valeur principale : construire une plateforme AWS, DevOps,
Kubernetes, GitOps et applicative comprehensible de bout en bout, sans ajouter
des composants dont la valeur pedagogique est secondaire.

Cet ADR supersede la partie de
[`ADR-001`](ADR-001-gitlab-com-for-ci.md) qui reservait le self-hosted a
`Gitea` pour le GitOps. `ADR-001` reste valide pour la decision principale :
utiliser `GitLab.com` comme plateforme CI/CD de reference.

References :

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md)
- [`docs/architecture/05-delivery-gitops.md`](../architecture/05-delivery-gitops.md)
- [`docs/gitops-structure.md`](../gitops-structure.md)
- [`docs/sprint-planning.md`](../sprint-planning.md)

## Decision

`Gitea` est retire de la cible MVP.

Le chemin GitOps cible devient :

```text
GitLab.com ou GitHub -> repository GitOps -> Argo CD -> Kubernetes
```

Argo CD reste la brique de reconciliation Kubernetes. Le repository GitOps sera
heberge sur une forge deja utilisee par le projet, en priorite `GitLab.com` si
l'on veut garder la CI et le repo GitOps dans le meme ecosysteme, ou `GitHub`
si l'on privilegie le repository actuel.

`Gitea` pourra rester mentionne uniquement comme extension optionnelle de lab,
non planifiee dans le MVP, pour demontrer un Git self-hosted plus tard si cela
redevient utile.

## Impact sur la Landing Zone

La suppression de `Gitea` n'a pas d'impact direct sur la Landing Zone AWS.

La Landing Zone reste centree sur :

- AWS Organizations ;
- les OUs et comptes ;
- les SCPs ;
- IAM Identity Center ;
- CloudTrail, Config, GuardDuty selon la posture ;
- les budgets, alertes de cout et baselines securite.

`Gitea` n'est pas une fondation AWS multi-compte. C'etait une brique applicative
/ plateforme deployable plus tard dans le workload Kubernetes. Le retirer ne
modifie donc pas les modules `aws-organization`, `aws-scp`, `aws-sso` ou
`aws-baseline`.

L'impact est surtout sur les sprints GitOps, Platform et CI/CD :

- remplacer les exemples `gitea.local/...` par GitLab.com ou GitHub ;
- supprimer le livrable de deploiement Helm Gitea ;
- supprimer ou archiver le playbook `ansible/playbooks/gitea-setup.yml` ;
- supprimer la route Cloudflare `gitea.*` du discours cible ;
- remplacer le token bot Gitea par un token GitLab/GitHub limite au repo
  GitOps ;
- mettre a jour les schemas et documents qui presentent encore Gitea comme
  composant cible.

## Alternatives considerees

### 1. Garder Gitea dans le chemin cible

Avantages :

- demontre un Git self-hosted ;
- permet de montrer une configuration post-deploiement par Ansible ;
- rend le lab moins dependant d'une forge SaaS.

Inconvenients :

- service supplementaire a deployer, sauvegarder, securiser et exposer ;
- tokens et permissions supplementaires ;
- complexite documentaire importante ;
- confusion avec GitLab.com et Argo CD ;
- faible valeur pour le MVP, car Argo CD a seulement besoin d'un repo Git.

Decision : rejetee pour le MVP.

### 2. Utiliser GitLab.com pour CI et GitOps

Avantages :

- un seul ecosysteme pour CI, repository applicatif et repository GitOps ;
- integration naturelle avec les tokens/protections GitLab ;
- moins de composants a operer dans le lab ;
- message plus clair en entretien.

Inconvenients :

- dependance accrue a GitLab.com ;
- moins de demonstration self-hosted.

Decision : option preferee si le repo GitOps est cree separement du repo
applicatif.

### 3. Utiliser GitHub pour le repo GitOps

Avantages :

- reutilise le repository deja existant ;
- tres simple pour le MVP local ;
- evite de multiplier les forges.

Inconvenients :

- le projet utilise deja GitLab.com pour la CI cible, donc le discours peut
  rester legerement bicephale ;
- il faudra cadrer precisement quel systeme pousse les commits GitOps.

Decision : option acceptable pour demarrer simplement.

## Consequences

Positives :

- reduction de la charge d'exploitation ;
- reduction de la surface d'attaque ;
- moins de secrets a gerer ;
- moins de cout et de stockage dans le workload ;
- GitOps plus facile a expliquer : Git existant, Argo CD, Kubernetes ;
- meilleure coherence avec l'objectif MVP.

Negatives :

- perte d'une demonstration self-hosted Git ;
- le playbook `gitea-setup.yml` devient obsolete ou doit etre archive ;
- plusieurs documents et schemas doivent etre realignes ;
- la strategie exacte du repo GitOps doit etre tranchee : GitLab.com ou GitHub.

## Impact Well-Architected

Excellence operationnelle :

- positif, car il y a moins de composants a installer, monitorer, sauvegarder
  et mettre a jour.

Securite :

- positif, car on retire une surface HTTP, des tokens admin et des permissions
  bot supplementaires.

Fiabilite :

- positif pour le MVP, car le chemin GitOps depend de moins de services
  auto-heberges.

Performance :

- neutre.

Couts :

- positif, car on evite stockage, compute, sauvegardes et exposition reseau
  associes a Gitea.

Durabilite :

- positif, car on reduit les ressources permanentes ou semi-permanentes du lab.

## Risques acceptes

- Le projet depend davantage d'une forge SaaS pour Git et CI.
- La demonstration "Git self-hosted" sort du chemin principal.
- Certains documents restent a realigner apres cet ADR tant que la suppression
  n'est pas appliquee dans tous les fichiers.

## Suivi de mise en oeuvre

Travail a faire dans un lot dedie :

- mettre a jour `ARCHITECTURE.md` ;
- mettre a jour `docs/sprint-planning.md` ;
- mettre a jour `docs/architecture/05-delivery-gitops.md` ;
- mettre a jour les schemas qui affichent Gitea ;
- retirer Gitea des routes Cloudflare cible ;
- supprimer ou archiver `ansible/playbooks/gitea-setup.yml` ;
- adapter les exemples `update-gitops-tag` vers GitLab.com ou GitHub ;
- mettre a jour `docs/CURRENT.md` et les docs de sprint concernees.

## Validation

Validation documentaire uniquement pour cet ADR :

```bash
git diff --check
```

Aucune modification runtime, Terraform, Ansible ou Kubernetes n'est appliquee
par cet ADR.
