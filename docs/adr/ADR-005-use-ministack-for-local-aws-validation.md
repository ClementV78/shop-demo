# ADR-005 - Utiliser MiniStack pour les validations AWS locales limitees

## Statut

Accepte

## Contexte

Le projet doit apprendre et valider des flux AWS sans consommer du vrai AWS a
chaque iteration. Un emulateur local aide a tester des appels AWS simples, les
profils CLI, certains endpoints et des scenarios de smoke test.

En revanche, les sujets AWS structurants comme Organizations, SCPs, IAM reel,
EKS manage ou comportements exacts de service doivent etre confirmes sur AWS
reel.

## Decision

MiniStack est utilise comme backend AWS local pour les validations rapides et
peu couteuses.

Il ne remplace pas AWS reel pour les decisions de securite, landing zone,
comptes, SCPs ou comportements manages critiques.

```text
MiniStack = smoke tests locaux et apprentissage rapide
AWS reel  = validation finale des services et controles structurants
```

## Consequences

Positives :

- moins de cout pendant les iterations ;
- feedback local plus rapide ;
- environnement reproductible via Ansible ;
- meilleure separation entre apprentissage local et validation cloud.

Negatives :

- risque de faux sentiment de compatibilite AWS ;
- certaines APIs sont absentes, partielles ou differentes ;
- une validation AWS reelle reste obligatoire avant de conclure.

## Suivi

Les docs et tests doivent indiquer explicitement ce qui est valide par
MiniStack et ce qui reste a verifier sur AWS reel.

Validation documentaire :

```bash
git diff --check
```
