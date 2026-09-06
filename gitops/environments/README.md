# Environments

Ce repertoire assemble les ressources a synchroniser par environnement.

Convention cible :

- `staging/` suit d'abord une branche de travail ou un chemin GitOps dedie ;
- `prod/` sera active plus tard via tags semver ou promotion explicite ;
- les deux environnements reutilisent les memes bases applicatives, avec des
  overlays separes.

La separation existe des maintenant pour eviter de melanger validation locale,
staging et production-like dans les prochains sprints.

