# Regles de travail et de suivi

> Ce document complete `AGENTS.md`. Il doit etre consulte avec
> `docs/CURRENT.md` avant toute modification du projet.

## Objectif

Le suivi doit rester utile, detaille au bon moment et versionne avec le projet.
Il sert a guider le travail, verifier les resultats et conserver des preuves
exploitables pour le portfolio.

## Limites

- Ne pas creer un fichier par tache.
- Limiter `CURRENT.md` a trois taches actives.
- Ne detailler completement que le sprint en cours.
- Garder les sprints futurs au niveau des objectifs et livrables dans
  `ROADMAP.md`.
- Ajouter une preuve uniquement pour une validation importante.
- Referencer une preuve existante au lieu de la dupliquer.
- Creer un ADR uniquement pour une decision structurante, couteuse ou difficile
  a inverser.
- Ne pas recopier `ARCHITECTURE.md` dans les fichiers de suivi : utiliser des
  liens vers ses sections.

## Etats

Les seuls etats utilises sont :

- `Planifie`
- `En cours`
- `Bloque`
- `Termine`

Un blocage doit indiquer sa cause et l'action necessaire pour le lever.

## Definition de termine

Une tache est `Terminee` lorsque :

- ses sous-taches necessaires sont realisees ;
- ses criteres d'acceptation sont valides ;
- les controles applicables ont reussi ;
- les preuves importantes sont referencees ;
- les limitations et risques residuels sont documentes.

Une implementation non validee reste `En cours`.

## Identifiants

Les elements d'un sprint suivent cette convention :

- Epic : `S0-E1`
- Tache : `S0-T1`
- Sous-tache : checklist sans identifiant supplementaire

Les identifiants restent stables, meme si l'ordre des taches change.

## Rituel de session

### Debut

1. Lire `AGENTS.md`, `docs/CONTRIBUTING.md` et `docs/CURRENT.md`.
2. Consulter le fichier du sprint actif.
3. Verifier les dependances et blocages.
4. Choisir au maximum trois taches actives.

### Pendant

1. Mettre a jour les changements d'etat significatifs.
2. Noter les ecarts avec `ARCHITECTURE.md`.
3. Conserver les resultats de validation utiles.
4. Creer un ADR si une decision structurante le justifie.

### Fin

1. Mettre a jour le fichier du sprint.
2. Actualiser `CURRENT.md`.
3. Actualiser `ROADMAP.md` si l'etat du sprint change.
4. Referencer les preuves importantes.
5. Indiquer la prochaine action concrete.

## Preuves

Une preuve peut etre :

- une commande de validation et son resultat synthetique ;
- un test automatise versionne ;
- un plan Terraform relu ;
- un manifeste rendu et valide ;
- une capture utile ;
- un lien vers un fichier, un rapport ou un runbook.

Les secrets, tokens, identifiants de comptes reels et sorties sensibles ne
doivent jamais etre conserves comme preuves.

## Repartition des documents

| Document | Responsabilite |
|---|---|
| `ARCHITECTURE.md` | Conception cible et arbitrages d'architecture |
| `docs/ROADMAP.md` | Vue globale et etat des sprints |
| `docs/CURRENT.md` | Travail actif et prochaine action |
| `docs/sprints/*.md` | Taches, dependances et criteres d'acceptation |
| `docs/adr/*.md` | Decisions structurantes |
| `docs/evidence/` | Preuves qui meritent un artefact dedie |
