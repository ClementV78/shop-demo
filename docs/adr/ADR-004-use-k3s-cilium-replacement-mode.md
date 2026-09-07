# ADR-004 - Utiliser k3s local avec Cilium en replacement mode

## Statut

Accepte

## Contexte

Le lab local doit fournir un Kubernetes reproductible, assez proche des sujets
reseau que l'on veut apprendre, sans chercher a simuler toute la production AWS.

Par defaut, k3s peut installer Flannel et kube-proxy. Le projet veut plutot
apprendre et valider Cilium, Hubble et les futures NetworkPolicies Cilium.

## Decision

Le cluster local utilise `k3s` sans le reseau par defaut :

```text
k3s : Flannel disabled, kube-proxy disabled, native NetworkPolicy disabled
Cilium : CNI, service load-balancing et NetworkPolicy
Hubble : observabilite reseau
```

Sur EKS, la cible reste differente : le VPC CNI AWS garde son role natif, et
Cilium sera traite comme une couche reseau/policy adaptee au contexte EKS.

## Consequences

Positives :

- apprentissage direct de Cilium ;
- moins de superposition entre Flannel, kube-proxy et Cilium ;
- validation locale utile avant les sujets EKS/GitOps ;
- Hubble disponible pour comprendre les flux.

Negatives :

- setup local plus exigeant qu'un k3s par defaut ;
- sensibilite aux IP locales, interfaces reseau et regles `ufw` ;
- certains tests Molecule restent limites par le conteneur de test.

## Suivi

Le role `k3s-install` doit rester explicite sur les flags k3s, et le role
`cilium-setup` doit documenter les valeurs critiques comme `k8sServiceHost`,
`devices` et les validations runtime.

Validation documentaire :

```bash
git diff --check
```
