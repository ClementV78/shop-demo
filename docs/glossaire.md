# Glossaire ShopDemo

Ce glossaire donne des definitions courtes, centrees sur ce projet. Il ne
remplace pas la documentation officielle des outils.

## Vue d'ensemble

| Terme | Definition courte | Dans ShopDemo |
|---|---|---|
| Internal Developer Platform | Ensemble d'outils et de workflows qui rendent le developpement, le deploiement et l'exploitation plus simples pour les equipes | Objectif portfolio global du projet |
| ShopDemo | Application e-commerce fictive servant de pretexte metier | Fil conducteur pour justifier l'architecture |
| Lab local | Environnement sur le serveur Ubuntu personnel | Permet de tester vite sans consommer AWS |
| Architecture cible | Etat vise a terme, pas forcement deja implemente | Decrite dans `ARCHITECTURE.md` |
| Sprint | Lot de travail borne avec livrables et preuves | Structure la progression du projet |
| Preuve | Commande, test, fichier ou resultat qui montre qu'un point est valide | Stockee ou referencee dans les docs de sprint |

## Infrastructure et IaC

| Terme | Definition courte | Dans ShopDemo |
|---|---|---|
| Terraform | Outil d'Infrastructure as Code pour creer les ressources cloud | Cree AWS, reseau, EKS, RDS, IAM, etc. |
| State Terraform | Fichier d'etat qui relie le code Terraform aux ressources reelles | Separe en `bootstrap` et `workload` |
| Bootstrap state | State permanent qui porte les fondations necessaires au reste | Runner, backend Terraform, OIDC |
| Workload state | State ephemere qui porte l'environnement applicatif | VPC, EKS, RDS, services AWS applicatifs |
| Ansible | Outil d'automatisation pour configurer des machines et services | Configure le serveur local, k3s, runners, hardening |
| Playbook | Fichier Ansible qui orchestre une ou plusieurs actions/roles | Exemple : `k3s-install.yml` |
| Role Ansible | Package de taches, variables et handlers reutilisables | Exemple : `roles/cilium-setup` |
| Handler | Action Ansible declenchee seulement si une tache notifie un changement | Exemple : redemarrer un service apres changement de config |
| Idempotence | Capacite a rejouer une automation sans changement inutile | Critere central des roles Ansible |
| Molecule | Outil de test pour roles Ansible | Verifie convergence, idempotence et assertions |

## Kubernetes

| Terme | Definition courte | Dans ShopDemo |
|---|---|---|
| Kubernetes | Orchestrateur de conteneurs | Runtime applicatif cible |
| k3s | Distribution Kubernetes legere | Utilisee dans le lab local |
| EKS | Kubernetes manage par AWS | Cible cloud du projet |
| Node | Machine qui execute les pods Kubernetes | Le mini-PC est le node local k3s |
| Pod | Plus petite unite executable Kubernetes | Contient un ou plusieurs conteneurs |
| Deployment | Objet Kubernetes qui gere des replicas de pods | Utilise pour services Go, CoreDNS, Hubble UI |
| DaemonSet | Objet Kubernetes qui lance un pod sur chaque node | Cilium agent tourne comme DaemonSet |
| Service | Abstraction reseau stable devant des pods | Expose CoreDNS, Hubble, services applicatifs |
| CNI | Plugin reseau Kubernetes | Cilium fournit le CNI du lab |
| kube-proxy | Composant Kubernetes historique pour router les Services | Desactive dans k3s local, remplace par Cilium |
| CoreDNS | DNS interne Kubernetes | Permet aux pods de resoudre les noms de services |
| Traefik | Ingress controller installe par defaut par k3s | Present localement, pas la cible finale de routage |
| Gateway API Kubernetes | API Kubernetes moderne pour decrire le routage | Cible avec NGINX Gateway Fabric |
| NGINX Gateway Fabric | Implementation NGINX de Gateway API | Prevue pour le routage applicatif sur EKS |

## Cilium et reseau

| Terme | Definition courte | Dans ShopDemo |
|---|---|---|
| Cilium | CNI base sur eBPF pour reseau, security policies et observabilite | Remplace Flannel/kube-proxy en local |
| eBPF | Technologie Linux permettant d'executer du code controle dans le noyau | Utilisee par Cilium pour router et observer |
| kube-proxy replacement | Mode ou Cilium prend en charge le routage des Services | Active sur le lab k3s |
| Hubble | Couche d'observabilite reseau de Cilium | Sert a voir les flux entre pods/services |
| Hubble relay | Service qui agrege les flux Hubble des agents Cilium | Permet une lecture centralisee des flux |
| Hubble UI | Interface web pour visualiser les flux Hubble | Activee dans le lab |
| Cilium agent | Pod Cilium qui tourne sur chaque node et programme le datapath | Doit etre `Running` pour que le reseau fonctionne |
| Cilium operator | Composant Cilium qui gere certaines ressources cluster | Un replica en local mono-noeud |
| Datapath | Chemin reel emprunte par les paquets reseau | Programme par Cilium via eBPF |
| Pod CIDR | Plage d'IP reservee aux pods | `10.42.0.0/16` dans le lab |
| Service CIDR | Plage d'IP virtuelles des Services Kubernetes | `10.43.0.0/16` avec k3s |
| Direct routing device | Interface reseau utilisee par Cilium pour sortir du node | `br0` sur le mini-PC |

## AWS

| Terme | Definition courte | Dans ShopDemo |
|---|---|---|
| AWS Organizations | Service pour organiser plusieurs comptes AWS | Base de la Landing Zone cible |
| IAM Identity Center | Gestion centralisee des acces humains AWS | Prevu pour les acces admin/dev |
| IAM | Gestion des identites et permissions AWS | Moindre privilege pour CI, pods et services |
| OIDC | Federation d'identite sans cle statique longue duree | GitLab CI vers AWS |
| VPC | Reseau prive AWS | Heberge EKS, RDS et services internes |
| RDS PostgreSQL | Base PostgreSQL managée par AWS | Persistence applicative cible |
| S3 | Stockage objet AWS | Frontend statique et backend Terraform |
| CloudFront | CDN AWS | Sert le frontend |
| WAF | Firewall applicatif AWS | Protection edge cible |
| Cognito | Authentification utilisateur managée | JWT pour proteger les APIs |
| SNS | Pub/sub managé AWS | Fan-out des evenements metier |
| SQS | Queue managée AWS | Consumers stock/notification et DLQ |
| DLQ | Queue d'erreurs pour messages non traites | Montre la resilience async |
| Lambda | Compute serverless AWS | Recoit le webhook paiement |
| API Gateway AWS | Front door HTTP managée AWS | Expose le webhook paiement |
| Karpenter | Autoscaler de nodes Kubernetes | Prevu pour optimiser cout et capacite EKS |
| IRSA | Association IAM role/service account sur EKS | Permissions AWS fines pour les pods |

## CI/CD, GitOps et securite

| Terme | Definition courte | Dans ShopDemo |
|---|---|---|
| GitLab CI | Moteur CI/CD utilise par le projet | Teste, scanne, build, pilote Terraform/GitOps |
| GitLab Runner | Agent qui execute les jobs GitLab CI | Local aujourd'hui, EC2 bootstrap plus tard |
| GitOps | Modele ou Git porte l'etat desire du cluster | Argo CD synchronise depuis Git |
| Argo CD | Controleur GitOps Kubernetes | Prevu au Sprint 1 |
| Kaniko | Build d'images conteneur sans daemon Docker privilegie | Prevu pour builds rootless |
| SBOM | Inventaire des composants logiciels d'une image ou application | Prevu comme preuve supply chain |
| Trivy | Scanner securite pour images, IaC et dependances | Prevu dans les pipelines |
| GitLeaks | Scanner de secrets dans Git | Deja utilise pour verifier le depot |
| Kyverno | Policy engine Kubernetes | Prevu pour guardrails admission |
| External Secrets Operator | Synchronise des secrets externes vers Kubernetes | Prevu pour eviter les secrets en clair |

## Observabilite et exploitation

| Terme | Definition courte | Dans ShopDemo |
|---|---|---|
| Observabilite | Capacite a comprendre l'etat du systeme via logs, metriques et traces | Sprint dedie prevu |
| Prometheus | Collecte et requete de metriques | Cible pour metriques Kubernetes/app |
| Grafana | Dashboards et visualisation | Cible pour exploitation |
| Loki | Stockage et requete de logs | Cible pour logs applicatifs |
| Fluent Bit | Agent de collecte de logs | Prevu pour envoyer les logs |
| Kubecost | Estimation et analyse des couts Kubernetes | Signal FinOps cible |
| SLO | Objectif de niveau de service mesure | Prevu pour cadrer les attentes |
| Runbook | Procedure operationnelle pour diagnostiquer/corriger | A associer aux alertes utiles |

## Agentique

| Terme | Definition courte | Dans ShopDemo |
|---|---|---|
| Agentique | Systeme ou un LLM decide quelles actions/tools appeler pour repondre | Extension MVP prevue |
| Tool | Fonction externe appelee par l'agent | Exemple cible : collecter des signaux |
| Signal | Donnee brute collectee par tool ou injectee par scenario de test | Entree normalisee du pipeline agentique |
| CityContext | Objet metier normalise derive des signaux | Base du scoring/review agentique cible |
| Scoring | Evaluation deterministe a partir du contexte | Partie explicable du pipeline |
| Review | Synthese finale justifiant le resultat | Sortie utilisateur du MVP agentique |
| `prompt` / `agentic` | Chemin produit principal | L'utilisateur formule une demande naturelle |
| `scenario_inline` | Signaux injectes directement pour tester | Surface de test, pas produit |
| `scenario_id` | Fixture locale issue d'un catalogue dev | Option dev locale seulement |
