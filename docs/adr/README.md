# Architecture Decision Records

Creer un ADR uniquement pour une decision structurante, couteuse ou difficile a
inverser.

Convention de nommage :

```text
ADR-001-titre-court.md
```

Un ADR contient au minimum : contexte, decision, alternatives, consequences,
statut et lien avec `ARCHITECTURE.md`.

## Index

| ADR | Statut | Decision |
|---|---|---|
| [`ADR-001`](ADR-001-gitlab-com-for-ci.md) | Accepte | Utiliser GitLab.com pour la CI/CD et ne pas auto-heberger GitLab |
| [`ADR-002`](ADR-002-remove-gitea-from-mvp.md) | Accepte | Retirer Gitea de la cible MVP GitOps |
| [`ADR-003`](ADR-003-separate-bootstrap-and-workload-states.md) | Accepte | Separer les states Terraform bootstrap et workload |
| [`ADR-004`](ADR-004-use-k3s-cilium-replacement-mode.md) | Accepte | Utiliser k3s local avec Cilium en replacement mode |
| [`ADR-005`](ADR-005-use-ministack-for-local-aws-validation.md) | Accepte | Utiliser MiniStack pour les validations AWS locales limitees |
| [`ADR-006`](ADR-006-structure-gitops-platform-apps-environments.md) | Accepte | Structurer GitOps en platform, apps et environments |
| [`ADR-007`](ADR-007-gitlab-source-of-truth-github-mirror.md) | Accepte | GitLab.com source de verite GitOps, GitHub en miroir public |
