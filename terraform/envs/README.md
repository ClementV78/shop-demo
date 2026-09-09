# States workload

Ce répertoire porte le state `workload`, **éphémère**, détruit hors session, conformément à [`ADR-003`](../../docs/adr/ADR-003-separate-bootstrap-and-workload-states.md).

Volontairement vide jusqu'au Sprint 3. Le state `workload` contient le VPC, EKS, RDS et les services AWS applicatifs, dont aucun n'existe avant ce sprint. L'ouvrir plus tôt reviendrait à créer un state vide sans usage.

La séparation est structurante et n'est pas une préférence de rangement : le state `bootstrap` héberge le bucket qui stocke le state `workload`. Si les deux vivaient ensemble, un `terraform destroy` détruirait le backend en cours d'utilisation par le destroy lui-même.
