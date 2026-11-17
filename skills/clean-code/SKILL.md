---
name: clean-code
description: Règles de Clean Code indépendantes du langage et du framework — noms, fonctions, commentaires, gestion d'erreurs, types, tests, odeurs de code, quand les principes se contredisent (DRY/YAGNI/KISS). À utiliser pour « clean code », « code propre », « refactorer », « revue de code », « nommer », « simplifier cette fonction », « code smell », « est-ce lisible ? », ou avant de rendre un changement terminé, quel que soit le projet (TypeScript, PHP, Python, Java, Go…). Pour la structure en couches / dépendances entre modules, utiliser clean-architecture.
---

# Clean Code

Règles d'écriture et de relecture du code, valables dans tous les langages. Exemples en TypeScript ; le principe se transpose.

**Priorité** : `CLAUDE.md` / `AGENTS.md` / lint du projet > ce skill > habitudes générales. Dans un projet existant, la **cohérence locale** l'emporte sur la préférence personnelle.

Périmètre : le code à l'intérieur d'un module (noms, fonctions, erreurs, tests). Pour la **séparation en couches** et le sens des dépendances → skill `clean-architecture`.

## 0. Avant d'écrire

1. Lire 2-3 fichiers voisins : copier le nommage, le style d'erreur, la façon de tester.
2. Repérer l'outillage (lint, formatter, types) et le lancer en fin de tâche.
3. Chercher si la fonction ou le type existe déjà avant d'en créer un.

## 1. Noms

Le nom doit révéler l'intention, sans commentaire.

| ❌ | ✅ | Pourquoi |
|---|---|---|
| `d`, `tmp`, `data`, `info`, `item` | `dateDeCreation`, `demande` | nomme le concept |
| `getData()` | `findMairiesProches()` | verbe + objet disent l'effet |
| `isNotActive` | `isInactive` | pas de double négation |
| `UserManager`, `Helper`, `Utils` | `UserProfileMapper`, `slugify` | « Manager/Helper » cachent une responsabilité floue |
| `handleClick2` | `submitPayment` | décrit l'effet, pas l'ordre de création |

- Prononçables, cherchables (pas de `x1`, `a`), pas d'abréviation maison.
- Une seule langue par couche (métier en français si le projet le fait, technique en anglais) : rester cohérent.
- Booléens : `isX`, `hasX`, `canX`. Fonctions : verbe. Classes/types : nom.
- Un fichier porte le nom de son export principal.
- Longueur proportionnelle à la portée : `i` dans une boucle de 3 lignes, un nom complet pour un export.

## 2. Fonctions

- **Une seule chose, un seul niveau d'abstraction.** Test : peut-on la nommer sans « et » ?
- **Courtes.** Si on a envie de séparer des « paragraphes » par un commentaire, extraire des fonctions nommées.
- **≤ 3 paramètres**, sinon un objet typé. Pas d'argument booléen qui change le comportement (`render(true)`) : deux fonctions ou un paramètre nommé.
- **Retours anticipés** plutôt que `if` imbriqués :

```ts
// ❌ pyramide
function discount(user: User | null) {
  if (user) { if (user.isVerified) { if (user.orders > 10) return 0.2; } }
  return 0;
}

// ✅ gardes
function discount(user: User | null): number {
  if (!user?.isVerified) return 0;
  if (user.orders <= 10) return 0;
  return LOYALTY_DISCOUNT;
}
```

- **Pas d'effet de bord caché** : `getX` ne modifie rien. Séparer commande (change l'état) et requête (retourne une valeur).
- **Pas de nombre ni de chaîne magique** : `LOYALTY_DISCOUNT = 0.2`, `SESSION_TTL_MS = 30 * 24 * 3600 * 1000`.
- **Conditions répétées sur un type** → `switch` exhaustif sur une union, ou polymorphisme.
- **Pas de paramètre de sortie** : retourner la valeur.

## 3. Commentaires

- Le meilleur commentaire est un meilleur nom.
- **Autorisés** : le *pourquoi* non évident (contrainte légale, contournement d'un bug tiers avec lien, choix de perf mesuré), un avertissement (« l'ordre compte »), un `TODO(ticket)` traçable.
- **Interdits** : paraphraser le code, code commenté (Git s'en souvient), journal de modifications, bannières `// ---- Section ----`.
- Doc d'API (JSDoc, docstring) sur ce qui est publié à d'autres équipes, pas sur chaque fonction privée.

## 4. Erreurs

- Erreurs **typées** pour les cas métier (`EmailAlreadyTakenError`) : nom explicite, contexte utile, traduites **en un seul endroit** (HTTP, UI, log).
- `try/catch` **étroit** autour de ce qui peut échouer, jamais autour d'un corps entier.
- **Jamais de `catch {}` muet** : gérer, relancer, ou journaliser avec contexte.
- `null` signifie « absent », pas « erreur ». Une erreur est une erreur.
- **Échouer tôt** : valider les préconditions en début de fonction.
- Ne pas exposer le message brut d'une erreur inattendue à l'utilisateur (fuite d'information) ; le journaliser côté serveur.

## 5. Données et types

- **Valider aux frontières** (entrée HTTP, formulaire, fichier, réponse d'API tierce), puis travailler avec des types fiables : *parse, don't validate*.
- Langage typé : pas de `any` / cast pour faire taire le compilateur ; `unknown` + garde de type ; **unions discriminées** pour les états plutôt que des booléens aux combinaisons impossibles :

```ts
type Loadable<T> =
  | { status: 'loading' }
  | { status: 'error'; error: Error }
  | { status: 'ready'; data: T };
```

- **Immuabilité** par défaut (`const`, `readonly`, copies) ; effets de bord isolés à la périphérie.
- **Primitive obsession** : quand une valeur porte une règle (`Email`, `Slug`, `Montant`), lui donner un type dédié.
- Types **dérivés** plutôt que dupliqués (`Pick`, `ReturnType`, inférence depuis le schéma).
- Exporter le minimum.

## 6. Structure du code

- **Composition plutôt qu'héritage.**
- **Cohésion** : ce qui change ensemble vit ensemble. Un fichier ≈ une responsabilité (>~300 lignes : se demander s'il en a deux).
- **Loi de Déméter** : parler à ses voisins directs, pas `a.b.c.d()`.
- **Pas de dossier `utils/` fourre-tout** : nommer par intention et placer près de l'usage.
- **Pas de code mort**, d'import inutilisé, de `console.log` / `print` oublié.

## 7. SOLID en pratique

| | Application |
|---|---|
| **S** responsabilité unique | une fonction = une tâche ; une classe = une raison de changer |
| **O** ouvert/fermé | ajouter un cas = ajouter du code (nouvelle implémentation), pas réécrire l'existant |
| **L** substitution | une implémentation respecte le contrat de l'interface (mêmes erreurs, mêmes cas limites) |
| **I** ségrégation | interfaces petites ; un client ne dépend que de ce qu'il utilise |
| **D** inversion | le code métier dépend d'abstractions, les détails sont injectés |

## 8. Quand les principes se contredisent

- **DRY vs lisibilité** : DRY vaut pour la **connaissance** dupliquée (une règle métier à deux endroits), pas pour du code qui se ressemble par accident.
- **Règle de trois** : tolérer une duplication, factoriser à la troisième occurrence, quand la forme commune est claire. Une mauvaise abstraction coûte plus cher que la duplication.
- **YAGNI** : n'ajouter une interface, une option ou un paramètre que pour un besoin **présent**.
- **Performance vs clarté** : écrire clair, mesurer, optimiser le goulot prouvé, commenter *pourquoi*.
- **KISS** : entre deux solutions correctes, la plus simple à relire.

## 9. Tests

- **Pyramide** : beaucoup de tests rapides sur la logique pure, quelques tests d'intégration sur les frontières (BDD, API), peu de E2E sur les parcours critiques.
- **Un test = un comportement**, nommé en phrase (`'rejette un mot de passe trop court'`). Structure Arrange / Act / Assert.
- Tester le **comportement**, pas l'implémentation.
- Pas de logique conditionnelle ni de dépendance à l'ordre d'exécution dans un test.
- **Un bug corrigé = un test qui l'aurait attrapé.**
- Du code difficile à tester signale souvent un couplage à défaire (voir `clean-architecture`).

## 10. Odeurs → réflexe

| Odeur | Réflexe |
|---|---|
| fonction > ~30 lignes | extraire des fonctions nommées |
| > 3 paramètres | objet typé |
| conditions imbriquées | gardes / retours anticipés |
| même `switch` répété | union discriminée / polymorphisme |
| même groupe de champs qui voyage partout | créer un type |
| commentaire qui explique le « quoi » | renommer |
| `flag` booléen en paramètre | scinder la fonction |
| classe qui fait tout (« God object ») | découper par responsabilité |
| changement qui touche 5 fichiers pour un seul concept | regrouper ce qui change ensemble |
| code mort, imports inutilisés | supprimer |

## 11. Relecture avant « terminé »

- [ ] Noms explicites, fonctions courtes, retours anticipés, pas de magie.
- [ ] Erreurs gérées et typées, aucun `catch` muet, entrées validées à la frontière.
- [ ] Pas de code mort, de log de debug, de TODO sans ticket.
- [ ] Tests du comportement ajouté ou corrigé ; lint, types et tests passent.
- [ ] Le diff ne contient **que** ce qui a été demandé : pas de refactoring opportuniste (un commit = une intention). Boy-scout seulement dans les lignes déjà touchées.

## Sources

- R. C. Martin, *Clean Code* (2008) ; Hunt & Thomas, *The Pragmatic Programmer* ; Fowler, *Refactoring* (catalogue d'odeurs de code).
