# MVP Agentique

[Retour a `ARCHITECTURE.md`](../../ARCHITECTURE.md)

## Objectif

Cette page cadre l'evolution agentique du projet avec un objectif principal :
garder une solution simple a comprendre, simple a tester et centree sur la
valeur ajoutee du MVP.

Le produit ne doit pas exposer plusieurs facons concurrentes d'appeler la meme
fonctionnalite. Le chemin nominal est une requete en langage naturel traitee par
un agent qui choisit ses tools. Les autres entrees existent uniquement pour
tester ou diagnostiquer des parties precises.

## Chemin Produit

Le seul mode produit cible est `prompt` / `agentic`.

```text
prompt utilisateur -> agent + tools -> signals -> CityContext -> scoring -> review
```

Lecture :

- l'utilisateur exprime son besoin en langage naturel ;
- le LLM decide quels tools appeler ;
- les reponses des tools deviennent des signaux normalises ;
- le pipeline metier construit le `CityContext`, calcule le scoring, puis
  produit la review.

La valeur ajoutee du MVP est la combinaison suivante :

- orchestration agentique visible : le systeme choisit les tools utiles ;
- pipeline metier explicable : scoring et review reposent sur des signaux
  normalises ;
- testabilite : le meme pipeline peut etre exerce avec des signaux controles.

## Entrees De Test

Les scenarios ne sont pas des modes produit.

| Entree | Usage | Contraintes |
|---|---|---|
| `scenario_inline` | Tester le runtime deploye avec des signaux fournis dans la requete | Aucun appel tool/API externe ; doit passer par le meme pipeline metier |
| `scenario_id` | Rejouer une fixture locale/dev si un catalogue existe | Optionnel ; ne doit pas apparaitre dans le discours produit |

`scenario_inline` est la voie de test prioritaire, car elle valide le runtime
de bout en bout sans dependre de la disponibilite d'API externes ni de la
decision non deterministe du modele.

`scenario_id` ne doit etre conserve que s'il apporte une vraie valeur de
developpement local. S'il cree de la confusion ou demande un catalogue non
deployee, il doit etre supprime dans une evolution separee.

## Mode `live`

Le mode `live` est supprime de la cible.

Raisons :

- il cree une promesse produit distincte du chemin agentique ;
- il rend la documentation plus difficile a comprendre ;
- il peut donner une impression de realisme sans garantir des signaux reels ;
- il ajoute une branche de code et de schema qui ne porte pas la valeur du MVP.

Les interfaces publiques, schemas, exemples et messages utilisateur ne doivent
plus proposer `live`. Si une requete entrante mentionne encore ce mode, elle
doit etre rejetee comme mode inconnu ou retire.

## Impacts Code Et Schemas

Etat actuel dans ce depot : aucune implementation applicative agentique,
aucun schema API et aucune collection Bruno associee n'ont ete trouves.
Les impacts ci-dessous servent donc de contrat pour l'implementation future.

Lorsque le code applicatif sera ajoute :

- retirer `live` des enums, dispatchers, handlers, routes, options CLI et
  schemas publics ;
- eviter une enum publique generique `mode` si elle pousse a presenter les
  scenarios comme des usages produit ;
- exposer d'abord une interface produit basee sur le prompt ;
- isoler `scenario_inline` dans une surface de test ou d'evaluation ;
- faire converger tous les adapters d'entree vers le meme pipeline
  `signals -> CityContext -> scoring -> review`.

Les tests attendus devront couvrir :

- le chemin produit `prompt` / `agentic` ;
- la reproductibilite de `scenario_inline` a signaux identiques ;
- le rejet de `live` ;
- l'absence d'appel tool/API externe depuis les tests a signaux injectes ;
- le caractere commun du pipeline de scoring et de review.
