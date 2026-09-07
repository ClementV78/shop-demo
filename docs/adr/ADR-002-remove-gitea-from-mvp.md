# ADR-002 - Retirer Gitea de la cible MVP GitOps

## Statut

Accepte

## Contexte

La cible initiale prevoyait `Gitea` comme serveur Git self-hosted pour heberger
un repo GitOps interne, cree et configure par Ansible. Avec le recul, cette
brique apporte peu au MVP : Argo CD a seulement besoin d'un repository Git
accessible, qu'il soit sur GitLab.com, GitHub, Gitea ou une autre forge.

Garder Gitea ajoute un service a deployer, sauvegarder, securiser, exposer et
documenter. Cela brouille aussi le message du projet en ajoutant une forge Git
alors que GitLab.com/GitHub et Argo CD couvrent deja le besoin GitOps.

Cet ADR supersede uniquement la partie de
[`ADR-001`](ADR-001-gitlab-com-for-ci.md) qui reservait le self-hosted a Gitea
pour GitOps. `ADR-001` reste valide pour la CI sur GitLab.com.

## Decision

Gitea est retire de la cible MVP.

Le chemin GitOps cible devient :

```text
GitLab.com ou GitHub -> repo GitOps -> Argo CD -> Kubernetes
```

Gitea peut rester une extension optionnelle de lab, mais il n'est plus un
livrable planifie ni une dependance du chemin principal.

## Impact

La Landing Zone AWS n'est pas impactee : Organizations, OUs, SCPs, IAM Identity
Center, CloudTrail, Config, GuardDuty et budgets restent inchanges.

L'impact concerne surtout GitOps, Ansible et la doc :

- remplacer les exemples `gitea.local/...` par GitLab.com ou GitHub ;
- retirer le livrable Helm Gitea ;
- supprimer ou archiver `ansible/playbooks/gitea-setup.yml` ;
- retirer `gitea.*` des routes Cloudflare cible ;
- remplacer le token bot Gitea par un token GitLab/GitHub limite au repo
  GitOps ;
- mettre a jour les schemas qui affichent encore Gitea.

## Consequences

Positives :

- moins de composants a operer ;
- moins de secrets et de surface d'attaque ;
- moins de cout et de stockage ;
- GitOps plus lisible : Git existant, Argo CD, Kubernetes.

Negatives :

- perte de la demonstration Git self-hosted ;
- besoin de realigner les docs et squelettes Ansible deja crees ;
- choix du repo GitOps a trancher explicitement : GitLab.com ou GitHub.

## Suivi

Un lot dedie devra nettoyer `ARCHITECTURE.md`, `docs/sprint-planning.md`,
`docs/architecture/05-delivery-gitops.md`, les schemas, les routes Cloudflare
cible et le playbook `gitea-setup.yml`.

Validation de cet ADR :

```bash
git diff --check
```
