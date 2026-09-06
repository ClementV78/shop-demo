# Catalogue des schemas

Ce repertoire contient les schemas du projet et leurs sources editables quand
elles existent.

Regle de lecture :

- `.svg` : rendu a afficher dans la documentation Markdown ;
- `.drawio` : source editable avec draw.io ;
- `.html` : rendu interactif genere par Archify ;
- `.png` : apercu ou export image ;
- `.json` : source de generation Archify ou sequence.

## Entrees de comprehension

| Schema | Rendu | Source | Utilise par |
|---|---|---|---|
| Vue README | [`readme-overview.svg`](readme-overview.svg) | [`readme-overview.drawio`](readme-overview.drawio) | `README.md` |
| Modele mental projet | [`comprendre-angle-1-modele-mental.svg`](comprendre-angle-1-modele-mental.svg) | [`comprendre-angle-1-modele-mental.drawio`](comprendre-angle-1-modele-mental.drawio) | `docs/comprendre-le-projet.md` |
| Local vs AWS | [`comprendre-angle-2-local-vs-aws.svg`](comprendre-angle-2-local-vs-aws.svg) | [`comprendre-angle-2-local-vs-aws.drawio`](comprendre-angle-2-local-vs-aws.drawio) | `docs/comprendre-le-projet.md` |
| Delivery et runtime | [`comprendre-angle-3-delivery-runtime.svg`](comprendre-angle-3-delivery-runtime.svg) | [`comprendre-angle-3-delivery-runtime.drawio`](comprendre-angle-3-delivery-runtime.drawio) | `docs/comprendre-le-projet.md` |

## Sprint 0 et Ansible

| Schema | Rendu | Source | Utilise par |
|---|---|---|---|
| Vue Ansible projet | [`ansible-overview-drawio.svg`](ansible-overview-drawio.svg) | [`ansible-overview-drawio.drawio`](ansible-overview-drawio.drawio) | `docs/ansible-structure.md` |
| Bootstrap / harden / teardown | [`ansible-bootstrap-teardown.svg`](ansible-bootstrap-teardown.svg) | [`ansible-bootstrap-teardown.drawio`](ansible-bootstrap-teardown.drawio) | `docs/ansible-structure.md` |
| Flux role k3s-install | [`k3s-install-role-flow-drawio.svg`](k3s-install-role-flow-drawio.svg) | [`k3s-install-role-flow-drawio.drawio`](k3s-install-role-flow-drawio.drawio) | `docs/ansible-structure.md` |
| Frontiere Terraform / Ansible | [`terraform-ansible-boundary.svg`](terraform-ansible-boundary.svg) | [`terraform-ansible-boundary.drawio`](terraform-ansible-boundary.drawio) | `docs/ansible-structure.md` |
| Execution Ansible Sprint 0 | [`concepts-s0-ansible-execution.svg`](concepts-s0-ansible-execution.svg) | [`concepts-s0-ansible-execution.drawio`](concepts-s0-ansible-execution.drawio) | `docs/concepts-sprint-0.md` |
| Contrat d'un role | [`concepts-s0-role-contract.svg`](concepts-s0-role-contract.svg) | [`concepts-s0-role-contract.drawio`](concepts-s0-role-contract.drawio) | `docs/concepts-sprint-0.md` |
| Cycle k3s / Cilium | [`concepts-s0-k3s-cilium-lifecycle.svg`](concepts-s0-k3s-cilium-lifecycle.svg) | [`concepts-s0-k3s-cilium-lifecycle.drawio`](concepts-s0-k3s-cilium-lifecycle.drawio) | `docs/concepts-sprint-0.md` |
| Test connectivite Cilium | [`cilium-connectivity-test.svg`](cilium-connectivity-test.svg) | [`cilium-connectivity-test.drawio`](cilium-connectivity-test.drawio) | Deep dive Cilium |
| MiniStack services emules | [`ministack-emulated-services.svg`](ministack-emulated-services.svg) | [`ministack-emulated-services.drawio`](ministack-emulated-services.drawio) | `docs/architecture/01-local-lab.md` |
| MiniStack infra locale | [`ministack-local-infra.svg`](ministack-local-infra.svg) | [`ministack-local-infra.drawio`](ministack-local-infra.drawio) | `docs/sprints/sprint-0-ansible.md` |
| Tunnels Cloudflare locaux | [`cloudflare-tunnels-local.svg`](cloudflare-tunnels-local.svg) | [`cloudflare-tunnels-local.drawio`](cloudflare-tunnels-local.drawio) | `docs/architecture/01-local-lab.md` |

## Sprint 1 et GitOps

| Schema | Rendu | Source | Utilise par |
|---|---|---|---|
| Vue GitOps locale | [`s1-gitops-local-overview.svg`](s1-gitops-local-overview.svg) | [`s1-gitops-local-overview.drawio`](s1-gitops-local-overview.drawio) | `docs/gitops-structure.md`, `docs/concepts-sprint-1.md` |
| Structure du repo GitOps | [`s1-gitops-repo-structure.svg`](s1-gitops-repo-structure.svg) | [`s1-gitops-repo-structure.drawio`](s1-gitops-repo-structure.drawio) | `docs/gitops-structure.md`, `docs/concepts-sprint-1.md` |
| Modele de promotion GitOps | [`s1-gitops-promotion-model.svg`](s1-gitops-promotion-model.svg) | [`s1-gitops-promotion-model.drawio`](s1-gitops-promotion-model.drawio) | `docs/gitops-structure.md`, `docs/concepts-sprint-1.md` |

## Architecture cible

| Schema | Rendu principal | Source | Rendu interactif |
|---|---|---|---|
| Plateforme cible | [`plateforme-cible.svg`](plateforme-cible.svg) | [`plateforme-cible.architecture.json`](plateforme-cible.architecture.json) | [`plateforme-cible.html`](plateforme-cible.html) |
| Organisation AWS | [`organisation-aws.svg`](organisation-aws.svg) | [`organisation-aws.architecture.json`](organisation-aws.architecture.json) | [`organisation-aws.html`](organisation-aws.html) |
| States Terraform | [`terraform-states.svg`](terraform-states.svg) | [`terraform-states.architecture.json`](terraform-states.architecture.json) | [`terraform-states.html`](terraform-states.html) |
| Runtime Kubernetes | [`flux-runtime-k8s.svg`](flux-runtime-k8s.svg) | [`flux-runtime-k8s.architecture.json`](flux-runtime-k8s.architecture.json) | [`flux-runtime-k8s.html`](flux-runtime-k8s.html) |
| Flux inter-pods Kubernetes | [`flux-inter-pods-k8s.svg`](flux-inter-pods-k8s.svg) | [`flux-inter-pods-k8s.architecture.json`](flux-inter-pods-k8s.architecture.json) | [`flux-inter-pods-k8s.html`](flux-inter-pods-k8s.html) |
| Control plane Kubernetes | [`control-plane-k8s.svg`](control-plane-k8s.svg) | [`control-plane-k8s.workflow.json`](control-plane-k8s.workflow.json) | [`control-plane-k8s.html`](control-plane-k8s.html) |
| Securite pods EKS | [`securite-pods-eks.svg`](securite-pods-eks.svg) | [`securite-pods-eks.architecture.json`](securite-pods-eks.architecture.json) | [`securite-pods-eks.html`](securite-pods-eks.html) |
| DevSecOps shift-left | [`devsecops-shift-left.svg`](devsecops-shift-left.svg) | [`devsecops-shift-left.workflow.json`](devsecops-shift-left.workflow.json) | [`devsecops-shift-left.html`](devsecops-shift-left.html) |
| Cout AWS | [`couts-aws.svg`](couts-aws.svg) | [`couts-aws.architecture.json`](couts-aws.architecture.json) | [`couts-aws.html`](couts-aws.html) |

## Delivery et application

| Schema | Rendu principal | Source | Rendu interactif |
|---|---|---|---|
| Flux achat et paiement | [`flux-achat-paiement-drawio.svg`](flux-achat-paiement-drawio.svg) | [`flux-achat-paiement-drawio.drawio`](flux-achat-paiement-drawio.drawio) | [`flux-achat-paiement.html`](flux-achat-paiement.html) |
| Sequence achat et paiement | [`flux-achat-paiement.svg`](flux-achat-paiement.svg) | [`flux-achat-paiement.sequence.json`](flux-achat-paiement.sequence.json) | [`flux-achat-paiement.html`](flux-achat-paiement.html) |
| Sequence runtime requete | [`flux-runtime-requete-k8s-sequence.svg`](flux-runtime-requete-k8s-sequence.svg) | [`flux-runtime-requete-k8s-sequence.drawio`](flux-runtime-requete-k8s-sequence.drawio) | - |
| Pipeline GitOps | [`pipeline-gitops.svg`](pipeline-gitops.svg) | [`pipeline-gitops.workflow.json`](pipeline-gitops.workflow.json) | [`pipeline-gitops.html`](pipeline-gitops.html) |
| Pipeline CI/CD | [`pipeline-cicd-overview.svg`](pipeline-cicd-overview.svg) | [`pipeline-cicd-overview.workflow.json`](pipeline-cicd-overview.workflow.json) | [`pipeline-cicd-overview.html`](pipeline-cicd-overview.html) |
| Architecture GitLab | [`gitlab-architecture.svg`](gitlab-architecture.svg) | [`gitlab-architecture.drawio`](gitlab-architecture.drawio) | - |
| Webhook paiement async | [`webhook-paiement-async.svg`](webhook-paiement-async.svg) | [`webhook-paiement-async.workflow.json`](webhook-paiement-async.workflow.json) | [`webhook-paiement-async.html`](webhook-paiement-async.html) |

## A nettoyer plus tard

- Harmoniser progressivement les noms historiques suffixes `-drawio` ou
  `-sequence`.
- Decider si les `.png` generes par Archify doivent rester versionnes ou etre
  traites comme exports regenerables.
- Eviter de deplacer massivement les fichiers tant que les documents Markdown
  pointent vers des chemins stables.
