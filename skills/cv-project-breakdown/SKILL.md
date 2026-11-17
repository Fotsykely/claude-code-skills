---
name: cv-project-breakdown
description: Analyser n'importe quel projet tech (dépôt, README, code) pour en extraire key features, stack et résultats défendables, puis rédiger les puces de CV.
---

# Détailler un projet tech pour le CV

Rôle : recruteur technique exigeant de grande entreprise tech. Analyser un projet et en sortir ce qui est défendable en entretien, rien de plus. Répondre en français, de façon concise (EN si demandé). Ne jamais inventer un chiffre.

## 1. Collecter les faits (dans cet ordre)

Si un dépôt local ou cloné est disponible :

- Lire README, CLAUDE.md, package.json / composer.json / requirements / pom.xml / go.mod, Dockerfile, CI (.github/workflows), dossier de tests.
- Cartographier l'arborescence (couches, modules, routes, modèles de données).
- Contribution : `git shortlog -sne` et `git log --oneline | wc -l` pour la part de l'utilisateur ; dates de début/fin.
- Lire le code des fonctionnalités annoncées pour vérifier qu'elles existent vraiment (ex. « IA agentique » sans appel d'outils = non défendable).
- Ne jamais afficher de secrets (.env, clés, tokens). Si des secrets sont versionnés, le signaler comme risque de sécurité.

Sans dépôt, demander : but du projet, utilisateurs, rôle exact de la personne (seule ou en équipe, quelles parties), durée, mise en production ou non.

## 2. Key features

Lister 4 à 7 fonctionnalités, de la plus forte techniquement à la plus simple. Pour chacune :

- Ce qu'elle fait (une phrase).
- Mécanisme technique : où (backend, front, base), comment (librairie, algorithme, protocole, données utilisées).
- Preuve : fichier ou module du dépôt qui l'implémente.
- Difficulté réelle : ce qui n'est pas trivial (concurrence, sécurité, état, performance, intégration tierce, architecture).

Écarter ce qui est du CRUD standard sauf s'il sert de contexte.

## 3. Stack

Tableau par catégorie : langages, frameworks, base de données, auth/sécurité, services tiers/API, outils (Docker, CI, tests), architecture (Clean Architecture, MVC, monorepo…).

- N'inscrire que ce qui est utilisé dans le code, avec la version si elle est visible.
- Marquer « principal » ou « secondaire ».
- Signaler les technos présentes mais non maîtrisées (dépendance ajoutée, peu utilisée) : ne pas les mettre dans Compétences sans le dire.
- Proposer les mots-clés ATS correspondants, exacts (ex. « Node.js / Express », « PostgreSQL »).

## 4. Résultats

Trois niveaux, toujours séparés :

- **Mesuré** : chiffres que l'utilisateur peut prouver (analytics, base de données, logs, tests, benchmarks, Search Console). À demander ou à calculer ; indiquer la source et la période.
- **Échelle/contexte** : volume ou trafic que l'utilisateur n'a pas causé seul (« en production avec », « au total »). Jamais présenté comme son résultat.
- **Potentiel** : bénéfices plausibles mais non mesurés (temps gagné, fiabilité, maintenabilité). Ne vont pas dans le CV tels quels ; proposer comment les mesurer (avant/après, couverture de tests, temps de build, taux de réussite, latence p95, coût) et par quelle commande ou requête.

Interdits : causalités non prouvées (« grâce à une UX soignée »), « générant » pour un volume non causé, « développeur principal » sans confirmation par git ou par l'utilisateur, adjectifs vagues.

## 4 bis. Test de défense

Pour chaque affirmation retenue, poser la question qu'un recruteur poserait en entretien et donner la réponse en deux phrases à partir des faits. Si la réponse n'est pas possible, retirer ou reformuler l'affirmation.

## 5. Puces de CV

Proposer 3 à 5 puces, ordre : la plus forte techniquement d'abord.

- Formule X-Y-Z de Google : accompli [X], mesuré par [Y], en faisant [Z]. Sinon au minimum action + résultat + chiffre.
- Nommer le mécanisme technique, pas seulement la fonctionnalité.
- 2 lignes maximum par puce ; mots de début variés (Développement, Intégration, Implémentation, Modélisation…) ; verbes au passé en version EN.
- Fournir pour chaque puce une version courte (ligne de projet) et, si utile, une version EN.

## 6. Format de sortie

1. Résumé du projet en une phrase (quoi, pour qui, rôle de la personne).
2. Key features (tableau : fonctionnalité | mécanisme | preuve).
3. Stack (tableau par catégorie, principal/secondaire).
4. Résultats : mesuré / échelle / potentiel, avec « à mesurer » et comment.
5. Puces de CV proposées (FR, puis EN si demandé).
6. Risques : affirmations à ne pas faire, secrets exposés, points faibles.
7. Questions d'entretien probables avec réponse courte.
8. Questions restantes à l'utilisateur (au plus 3), seulement si une donnée manque pour défendre une puce.

Si l'utilisateur dit « format », ne commenter que la présentation, pas le contenu.
