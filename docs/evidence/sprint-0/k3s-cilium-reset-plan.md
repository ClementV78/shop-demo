# Preuve - reset k3s/Cilium local

Date : 2026-09-05

Etat : applique.

## Objectif

Remettre le lab Kubernetes local dans un etat coherent avant de clore `S0-T13`.

Etat attendu :

- IP hote stable : `192.168.31.106` sur `br0`.
- Plus de reference runtime active a `192.168.31.200`.
- k3s reinstalle par Ansible avec les flags reseau attendus.
- Cilium reinstalle en replacement mode avec `k8sServiceHost` resolu vers l'IP actuelle du noeud.
- Pas de file Cilium `deleteQueue` bloquee.
- Validation runtime suffisamment propre pour documenter la preuve Sprint 0.

## Cause probable

La configuration projet et la documentation pointent vers `192.168.31.106`.
Les logs k3s montrent pourtant des tentatives vers `192.168.31.200`.
La recherche a trouve cette ancienne IP dans l'etat Kubernetes embarque de k3s,
notamment via des entrees `/registry/masterleases/192.168.31.200`.

Comme ce cluster est un lab reproductible, on evite d'editer la base k3s a la
main. On prefere reconstruire proprement l'etat local via Ansible.

## Etapes

1. Capturer l'etat avant action :
   - reseau hote ;
   - service k3s ;
   - processus residuels k3s/Cilium ;
   - logs utiles ;
   - presence de `192.168.31.200`.

2. Arreter proprement k3s si necessaire.

3. Reinitialiser le perimetre k3s/Cilium local :
   - utiliser le script de desinstallation k3s si disponible ;
   - verifier les processus restants ;
   - nettoyer uniquement les repertoires runtime/state appartenant a k3s/Cilium ;
   - ne pas toucher a Docker global, libvirt, Home Assistant, Immich, Nextcloud,
     Vaultwarden, AdGuard, Coolify ou aux autres services personnels.

4. Relancer Ansible :
   - `k3s-install.yml` ;
   - `cilium-setup.yml` ;
   - puis, si l'etat est propre, le bootstrap complet ou la validation S0-T13.

5. Valider :
   - `systemctl is-active k3s` ;
   - `kubectl get nodes -o wide` ;
   - `kubectl get pods -A` ;
   - absence de logs recents vers `192.168.31.200` ;
   - Cilium/CoreDNS/Hubble en etat coherent.

## Risques et limites

- Le reset supprime l'etat Kubernetes local. C'est acceptable pour le lab si
  aucun workload local important n'est a conserver.
- Cette action ne doit pas supprimer de ressources AWS.
- Cette action ne doit pas supprimer de donnees Docker ou libvirt hors k3s.
- Si k3s/Cilium conserve des processus orphelins, un nettoyage manuel cible
  peut etre necessaire.

## Resultat

- Diagnostics avant reset conserves sous `/tmp/shopdemo-k3s-reset-20260905/`.
- k3s a ete desinstalle puis reinstalle via
  `ansible/playbooks/k3s-install.yml`.
- Cilium a ete corrige pour fixer explicitement l'interface datapath via
  `devices: br0`, derivee de `ansible_facts['default_ipv4']['interface']`.
- Le role `cilium-setup` applique Helm sans `--wait`, puis attend explicitement
  le DaemonSet Cilium, CoreDNS, Hubble relay et Hubble UI.
- Validation finale : `k3s-install.yml` et `cilium-setup.yml` repassent avec
  `changed=0`, le noeud est `Ready`, et les pods systeme sont `Running` ou
  `Completed`.
