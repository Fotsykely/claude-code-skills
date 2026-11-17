# Clean Code — TypeScript & React

Adapté de *Clean Code* (R. C. Martin) au contexte TypeScript/React. Les principes ne sont pas des lois : quand deux principes se contredisent, voir § 8.

## 1. Noms

| ❌ | ✅ | Pourquoi |
|---|---|---|
| `const d = new Date()` | `const dateDeCreation = new Date()` | l'intention se lit sans contexte |
| `getData()` | `findMairiesProches()` | le verbe et l'objet disent ce qui se passe |
| `isNotActive` | `isInactive` / `isActive` + `!` | évite la double négation |
| `data`, `info`, `item`, `tmp` | nom du concept (`demande`, `departement`) | « data » ne dit rien |
| `handleClick2` | `handleSubmitPayment` | le nom décrit l'effet, pas l'ordre de création |
| `UserManager`, `Helper`, `Utils` | `UserProfileMapper`, `slugify` | « Manager/Helper » cachent l'absence de responsabilité claire |

Conventions TS/React : composants et types en `PascalCase`, fonctions/variables en `camelCase`, constantes `SCREAMING_SNAKE_CASE`, hooks `useXxx`, booléens `isX` / `hasX` / `canX`, handlers `handleX` côté composant et `onX` en prop. Un fichier porte le nom de son export principal (`SearchMairiesUseCase.ts`).

## 2. Fonctions

- **Une seule chose**, à un seul niveau d'abstraction. Test : peut-on la nommer sans « et » ?
- **Courtes** : si on a besoin d'un commentaire pour délimiter des paragraphes, extraire des fonctions.
- **≤ 3 paramètres** ; au-delà, un objet typé. Pas d'argument booléen qui change le comportement (`render(true)`) : deux fonctions ou un paramètre nommé.
- **Retours anticipés** :

```ts
// ❌ pyramide
function getDiscount(user: User | null) {
  if (user) {
    if (user.isVerified) {
      if (user.orders > 10) return 0.2;
    }
  }
  return 0;
}

// ✅ gardes
function getDiscount(user: User | null): number {
  if (!user?.isVerified) return 0;
  if (user.orders <= 10) return 0;
  return LOYALTY_DISCOUNT;
}
```

- **Pas d'effet de bord caché** : une fonction qui s'appelle `getX` ne modifie rien. Séparer commande et requête.
- **Pas de nombres magiques** : `const LOYALTY_DISCOUNT = 0.2`, `const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000`.
- **Éviter la répétition de conditions** sur un type : `switch` exhaustif sur une union discriminée plutôt qu'une chaîne de `if`.

## 3. Commentaires

- Le meilleur commentaire est un meilleur nom.
- Autorisés : le **pourquoi** non évident (contrainte légale, contournement d'un bug tiers avec lien, choix de perf mesuré), un avertissement (« l'ordre compte »), un `TODO(ticket)` traçable.
- Interdits : paraphraser le code, code commenté (Git s'en souvient), journal de modifications, bannières `// ---- Section ----`.
- La doc d'API publique (JSDoc) est utile sur les fonctions exportées d'une bibliothèque interne, pas sur chaque fonction privée.

## 4. TypeScript

- `strict: true` obligatoire. Pas de `any` : `unknown` + garde de type, ou un vrai type.
- Pas de `as X` pour contourner une erreur : corriger le type ou valider à l'exécution.
- **Unions discriminées** pour les états :

```ts
type Loadable<T> =
  | { status: 'loading' }
  | { status: 'error'; error: Error }
  | { status: 'ready'; data: T };
```
  Plus de couples `isLoading` + `error` + `data` aux combinaisons impossibles.
- **Types dérivés** plutôt que dupliqués : `Pick<User, 'id' | 'email'>`, `ReturnType`, `z.infer<typeof schema>`.
- **`readonly` / `as const`** pour les données figées ; `satisfies` pour valider sans élargir.
- **Parse, don't validate** : on transforme l'entrée non fiable en type fiable une fois, à la frontière (HTTP, formulaire, API tierce) ; l'intérieur n'a plus à revérifier.
- Pas d'`enum` TS numérique ; préférer une union de littéraux ou un objet `as const`.
- Exporter le minimum ; pas d'export par défaut pour ce qui n'est pas une page/layout (Next l'exige pour `page.tsx`, `layout.tsx`).

## 5. Gestion des erreurs

- Exceptions typées pour les cas **métier** (`EmailAlreadyTakenError`) ; elles ont un nom, portent le contexte utile, et sont traduites en un seul endroit.
- `try/catch` étroit autour de ce qui peut échouer, jamais autour de tout un corps de fonction.
- Jamais de `catch {}` vide. Soit gérer, soit relancer, soit journaliser avec contexte.
- Ne pas renvoyer `null` pour signifier « erreur » : `null` signifie « absent » ; une erreur est une erreur.
- Ne pas exposer le message d'une erreur inattendue à l'utilisateur.
- Échouer tôt : valider les préconditions au début.

## 6. React

- **Un composant = une responsabilité** : affichage d'un côté, logique (hook) de l'autre. Au-delà de ~150 lignes ou de 3 `useState` indépendants, extraire.
- **Hooks custom** (`useCountdown`, `useDebouncedValue`) pour réutiliser une logique d'état/effet ; un hook ne rend pas de JSX.
- **État minimal et dérivé** : ne pas stocker ce qui se calcule (`fullName = first + ' ' + last` à chaque rendu, pas un `useState`). L'état vit au plus bas niveau qui en a besoin ; ne remonter que si nécessaire.
- **`useEffect` en dernier recours** : pas pour dériver un état, pas pour réagir à un événement (utiliser le handler), pas pour charger des données initiales (Server Component). Il synchronise avec un système externe.
- **Clés stables** dans les listes (`key={id}`), jamais l'index si la liste change.
- **Pas de prop drilling profond** : composition (`children`, slots) d'abord ; Context seulement pour une donnée vraiment transversale.
- **Pas de `useMemo`/`useCallback` par défaut** ; avec React Compiler, encore moins. Profiler d'abord.
- **Props** : type nommé `Props`, champs minimaux, valeurs par défaut explicites ; pas de props « fourre-tout » (`config: any`).
- **JSX lisible** : pas de ternaires imbriqués ; extraire un sous-composant ou une variable nommée.
- **Accessibilité** comme partie du « done » (voir `nextjs-frontend.md` § 9).

## 7. SOLID appliqué ici

| Principe | Application concrète |
|---|---|
| **S** — responsabilité unique | un use case = une intention ; un composant = un rôle ; un fichier = un export principal |
| **O** — ouvert/fermé | ajouter un fournisseur de paiement = nouvel adapter + ligne dans le container, sans modifier les use cases |
| **L** — substitution de Liskov | `InMemoryXxxRepository` doit se comporter comme `PrismaXxxRepository` pour le contrat du port (mêmes erreurs, mêmes cas limites) |
| **I** — ségrégation des interfaces | ports petits et ciblés ; un use case ne dépend que des méthodes dont il a besoin (envisager de scinder un port qui dépasse ~7 méthodes) |
| **D** — inversion des dépendances | les use cases dépendent d'interfaces du domaine ; les implémentations sont injectées par le container |

## 8. Quand les principes se contredisent

- **DRY vs lisibilité/KISS** : DRY vaut pour la **connaissance** dupliquée (une règle métier dans deux endroits), pas pour du code qui se ressemble par accident. Deux fragments qui évolueront pour des raisons différentes restent séparés.
- **Règle de trois** : tolérer une duplication, factoriser à la troisième occurrence, quand la forme commune est claire.
- **YAGNI vs extensibilité** : n'ajouter une interface, un paramètre ou une option que pour un besoin **présent**. Prévoir le futur = coût sûr pour un bénéfice hypothétique.
- **Performance vs clarté** : écrire clair, mesurer, optimiser le goulot prouvé, et commenter *pourquoi*.
- **Cohérence vs « meilleure » pratique** : dans un projet existant, la cohérence locale l'emporte sur la préférence personnelle ; migrer par lots délibérés, pas fichier par fichier au hasard.

## 9. Tests

- **Pyramide** : beaucoup de tests de use cases/fonctions pures (rapides, sans I/O), quelques tests d'intégration d'adapters (BDD réelle ou conteneur), peu de tests E2E sur les parcours critiques (paiement, connexion).
- Un test = un comportement ; nom en phrase (`'rejette un mot de passe faible'`). Structure Arrange / Act / Assert.
- Tester le **comportement**, pas l'implémentation (pas d'assertion sur des appels internes sauf frontière externe).
- Pas de logique conditionnelle dans les tests ; données explicites, pas de dépendance à l'ordre d'exécution.
- Un bug corrigé = un test qui l'aurait attrapé.

## 10. Odeurs de code → réflexe

| Odeur | Réflexe |
|---|---|
| fonction > ~30 lignes | extraire des fonctions nommées |
| > 3 paramètres | objet typé |
| conditions imbriquées | gardes / retours anticipés |
| `switch` répété sur le même type | union discriminée ou polymorphisme |
| même groupe de champs qui voyage partout | créer un type/value object |
| fichier > ~300 lignes | scinder par responsabilité |
| commentaire qui explique le « quoi » | renommer |
| import qui remonte (`../../..`) | alias `@/`, ou la dépendance est dans la mauvaise couche |
| primitive obsession (`string` partout) | types dédiés / value objects (`Email`, `Slug`) quand une validation s'y attache |
| code mort, imports inutilisés | supprimer (Git garde l'historique) |

## 11. Avant de dire « terminé »

1. Relire le diff comme un relecteur : noms, taille des fonctions, couche respectée.
2. Lint + `tsc --noEmit` + build + tests.
3. Aucune donnée sensible exposée au client ; entrées validées ; erreurs gérées.
4. Pas de refactoring non demandé dans le même changement : un commit = une intention.
