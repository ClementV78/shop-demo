# ADR-003 - Separer les states Terraform bootstrap et workload

## Statut

Accepte

## Contexte

Le projet doit creer des fondations durables, puis des environnements AWS
ephemeres que l'on peut detruire hors session pour maitriser les couts.

Si le runner, le backend Terraform et les ressources applicatives vivent dans
le meme state, un `terraform destroy` du workload peut detruire les fondations
dont il depend, voire le runner qui execute l'operation.

## Decision

Terraform est separe en deux cycles de vie :

```text
bootstrap = permanent : backend state, lock, OIDC, runner et fondations CI
workload  = ephemere  : VPC, EKS, RDS, app, edge et services de session
```

Le state `bootstrap` ne doit pas dependre du state `workload`. Le state
`workload` peut etre applique et detruit regulierement sans supprimer les
fondations necessaires a son propre cycle de vie.

## Consequences

Positives :

- destruction du workload plus sure ;
- separation claire entre fondations et ressources couteuses ;
- meilleur controle FinOps ;
- reprise plus simple apres incident de deploiement.

Negatives :

- plus de documentation de state ;
- passage d'outputs entre states a cadrer proprement ;
- discipline stricte necessaire sur les dependances Terraform.

## Suivi

Cette decision devra etre verifiee dans les futurs roots Terraform :
`bootstrap`, `landing-zone` et `workload`.

Validation documentaire :

```bash
git diff --check
```
