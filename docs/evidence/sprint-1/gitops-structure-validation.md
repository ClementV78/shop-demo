# Preuve S1-T1 - Structure GitOps locale

Date : 2026-09-06

## Perimetre

Cette preuve couvre le cadrage `S1-T1` :

- structure [`../../../gitops/`](../../../gitops/) ;
- manifests de namespaces ;
- rendus Kustomize ;
- validation YAML ;
- validation schema Kubernetes ;
- validation et export des schemas Draw.io.

Aucun `kubectl apply` n'a ete execute dans ce controle.

## Commandes executees

```bash
kubectl kustomize gitops/platform
kubectl kustomize gitops/environments/staging
kubectl kustomize gitops/environments/prod
yamllint gitops
kubectl kustomize gitops/platform | kubeconform -strict -ignore-missing-schemas
kubectl kustomize gitops/environments/staging | kubeconform -strict -ignore-missing-schemas
kubectl kustomize gitops/environments/prod | kubeconform -strict -ignore-missing-schemas
python3 ~/.agents/skills/drawio-skill/scripts/validate.py docs/diagrams/s1-gitops-local-overview.drawio --score
python3 ~/.agents/skills/drawio-skill/scripts/validate.py docs/diagrams/s1-gitops-repo-structure.drawio --score
python3 ~/.agents/skills/drawio-skill/scripts/validate.py docs/diagrams/s1-gitops-promotion-model.drawio --score
git diff --check
```

## Resultat

| Controle | Resultat |
|---|---|
| Rendu `gitops/platform` | OK, rend les namespaces `argocd` et `gateway-system` |
| Rendu `gitops/environments/staging` | OK, rend le namespace `shopdemo-staging` |
| Rendu `gitops/environments/prod` | OK, rend le namespace `shopdemo-prod` |
| `yamllint gitops` | OK |
| `kubeconform` sur les rendus Kustomize | OK |
| Validation Draw.io | OK, `0 error(s), 0 warning(s)` sur les 3 schemas |
| Export SVG Draw.io | OK |
| `git diff --check` | OK |

## Limites

- Les manifests n'ont pas ete appliques au cluster.
- Argo CD n'est pas encore installe.
- Les futurs `ApplicationSet`, NetworkPolicies et workloads applicatifs ne sont
  pas couverts par cette preuve.
- Depuis `S1-T2`, `gitops/argocd/install.yaml` est exclu par `.yamllint` car
  c'est un manifest upstream genere. Il reste valide par dry-run Kubernetes
  server-side, pas par les regles de style YAML du depot.
